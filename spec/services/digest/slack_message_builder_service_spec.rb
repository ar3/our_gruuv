# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::SlackMessageBuilderService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  describe '#main_message' do
    it 'returns hash with :blocks and :text' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.main_message

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      expect(result[:blocks]).to be_an(Array)
      expect(result[:text]).to be_a(String)
    end

    it 'uses company label for get_shit_done in the message when no items' do
      create(:company_label_preference, company: organization.root_company || organization, label_key: 'get_shit_done', label_value: 'Action Items')
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.main_message

      expect(result[:text]).to include('Action Items')
    end

    it 'includes a link to configure digest in blocks' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.main_message

      context_block = result[:blocks].find { |b| b[:type] == 'context' }
      expect(context_block).to be_present
      expect(context_block.dig(:elements, 0, :text)).to include('Digest settings').or include('digest')
    end
  end

  describe '#gsd_thread_payloads' do
    it 'returns array of payloads, each with :blocks and :text' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.gsd_thread_payloads

      expect(result).to be_an(Array)
      expect(result).not_to be_empty
      result.each do |payload|
        expect(payload).to have_key(:blocks)
        expect(payload).to have_key(:text)
      end
      # With no items, single "All categories are clear." thread
      expect(result.first[:text]).to include('All categories are clear')
    end

    it 'returns one thread per GSD category that has items' do
      company = organization.root_company || organization
      goal = create(:goal, owner: teammate, creator: teammate, title: 'My Goal')
      manager_teammate = CompanyTeammate.find_or_create_by!(person: create(:person), organization: organization)
      assignment = create(:assignment, company: company)
      check_in = create(:assignment_check_in,
                        teammate: teammate,
                        assignment: assignment,
                        manager_completed_at: 1.day.ago,
                        manager_completed_by_teammate: manager_teammate,
                        employee_completed_at: nil)
      gsd_items = {
        total_pending: 2,
        observable_moments: [],
        maap_snapshots: [],
        observation_drafts: [],
        goals_needing_check_in: [goal],
        check_ins_awaiting_input: [check_in]
      }
      allow(GetShitDoneQueryService).to receive(:new).and_return(instance_double(GetShitDoneQueryService, all_pending_items: gsd_items))
      allow(Digest::AboutMeContentService).to receive(:new).and_return(instance_double(Digest::AboutMeContentService, sections: []))

      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.gsd_thread_payloads

      expect(result.length).to eq(2) # Goal Check-ins + Check-ins Awaiting Your Input
      expect(result.map { |p| p[:text] }.join).to include('Goal Check-ins')
      expect(result.map { |p| p[:text] }.join).to include('Check-ins Awaiting Your Input')
    end

    it 'escapes user content so Slack mrkdwn does not get invalid_blocks (e.g. < and > in goal titles)' do
      goal = create(:goal, owner: teammate, creator: teammate, title: 'Goal with <angle> brackets & ampersand')
      gsd_items = {
        total_pending: 1,
        observable_moments: [], maap_snapshots: [], observation_drafts: [],
        goals_needing_check_in: [goal],
        check_ins_awaiting_input: []
      }
      allow(GetShitDoneQueryService).to receive(:new).and_return(instance_double(GetShitDoneQueryService, all_pending_items: gsd_items))
      allow(Digest::AboutMeContentService).to receive(:new).and_return(instance_double(Digest::AboutMeContentService, sections: []))

      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.gsd_thread_payloads

      goal_payload = result.find { |p| p[:text].include?('Goal') }
      expect(goal_payload).to be_present
      expect(goal_payload[:text]).not_to include('<angle>')
      expect(goal_payload[:text]).to include('&lt;angle&gt;').or include('&amp;')
    end

    it 'formats check-ins awaiting input as subject (other person checked-in time ago)' do
      company = organization.root_company || organization
      manager_person = create(:person, first_name: 'Manager', last_name: 'User')
      manager_teammate = CompanyTeammate.find_or_create_by!(person: manager_person, organization: organization)
      assignment = create(:assignment, company: company, title: 'Q1 Revenue Target')
      check_in = create(:assignment_check_in,
                        teammate: teammate,
                        assignment: assignment,
                        manager_completed_at: 2.days.ago,
                        manager_completed_by_teammate: manager_teammate,
                        employee_completed_at: nil)
      gsd_items = {
        total_pending: 1,
        observable_moments: [],
        maap_snapshots: [],
        observation_drafts: [],
        goals_needing_check_in: [],
        check_ins_awaiting_input: [check_in]
      }
      allow(GetShitDoneQueryService).to receive(:new).and_return(instance_double(GetShitDoneQueryService, all_pending_items: gsd_items))
      allow(Digest::AboutMeContentService).to receive(:new).and_return(instance_double(Digest::AboutMeContentService, sections: []))

      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.gsd_thread_payloads

      check_in_payload = result.find { |p| p[:text].include?('Q1 Revenue Target') }
      expect(check_in_payload).to be_present
      expect(check_in_payload[:text]).to include('Manager')
      expect(check_in_payload[:text]).to match(/checked-in \d+ (day|days) ago/)
    end
  end

  describe '#about_me_main_payload' do
    it 'includes weekly header with top 1:1 focus beside image, action-item divider, then About summary' do
      allow(OneOnOne::PriorityCarouselBuilder).to receive(:call).and_return(
        {
          priorities: [
            {
              needs_attention: true,
              title: 'Example priority',
              reason: 'Example reason.',
              cta_kind: :bulk_goals,
              cta_label: 'Create goals'
            }
          ],
          needs_attention_count: 1,
          total_count: 13,
          first_attention_index: 0
        }
      )

      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.about_me_main_payload

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      expect(result[:blocks].size).to be >= 3

      header_text = result[:blocks].first.dig(:text, :text)
      expect(header_text).to match(/\|Weekly 1:1 check-in> for /)
      expect(header_text).to include('Top 1:1 focus')
      expect(header_text).to include('Example priority')
      expect(header_text).to include('Example reason.')
      expect(header_text).to include('Primary action:')

      summary_block = result[:blocks].last
      summary_text = summary_block.dig(:text, :text)
      expect(summary_text).to include('healthy')
      expect(summary_text).to include('It is time for our weekly check-in.')
      expect(summary_text).not_to include('Top 1:1 focus')
      expect(summary_text).to match(
        /\d+ <https?:\/\/[^|]+\|About #{Regexp.escape(person.casual_name)}> sections are healthy/
      )

      expect(result[:text]).to include('healthy')
      expect(result[:text]).to include('It is time for our weekly check-in.')
      expect(result[:text]).not_to include('Top 1:1 focus')
    end

    it 'links Asana urgent tasks title to the teammate 1:1 Asana URL when that is the top focus' do
      create(:one_on_one_link, teammate: teammate, url: 'https://app.asana.com/0/111/222')
      asana_title = OneOnOne::PriorityCarouselBuilder::ASANA_URGENT_TASKS_TITLE
      allow(OneOnOne::PriorityCarouselBuilder).to receive(:call).and_return(
        {
          priorities: [
            {
              needs_attention: true,
              title: asana_title,
              reason: 'Sync first.',
              cta_kind: :sync_anchor,
              cta_label: 'Sync Asana now',
              concrete_items: [],
              remaining_count: 0
            }
          ],
          needs_attention_count: 1,
          total_count: 13,
          first_attention_index: 0
        }
      )

      builder = described_class.new(teammate: teammate, organization: organization)
      header_text = builder.about_me_main_payload[:blocks].first.dig(:text, :text)

      expect(header_text).to include("<https://app.asana.com/0/111/222|#{asana_title}>")
    end

    it 'lists Asana urgent tasks in a separate block below the top focus header' do
      create(:one_on_one_link, teammate: teammate, url: 'https://app.asana.com/0/111/222')
      asana_title = OneOnOne::PriorityCarouselBuilder::ASANA_URGENT_TASKS_TITLE
      allow(OneOnOne::PriorityCarouselBuilder).to receive(:call).and_return(
        {
          priorities: [
            {
              needs_attention: true,
              title: asana_title,
              reason: 'There are tasks overdue or due in the next week.',
              cta_kind: :sync_anchor,
              cta_label: 'Open urgent Asana tasks',
              data_kind: :asana_tasks_attention,
              items: [{ task: { 'gid' => 'taskgid1', 'name' => 'Task A', 'due_on' => '2026-01-01' }, project_id: '111' }],
              remaining_count: 2
            }
          ],
          needs_attention_count: 1,
          total_count: 13,
          first_attention_index: 0
        }
      )

      builder = described_class.new(teammate: teammate, organization: organization)
      blocks = builder.about_me_main_payload[:blocks]
      bullets_block = blocks.find { |b| b.dig(:text, :text).to_s.include?('Task A') }
      bullets_text = bullets_block.dig(:text, :text)

      expect(bullets_text).to include('Task A')
      expect(bullets_text).to include('• _+2 more_')
    end
  end

  describe '#about_me_priorities_thread_payload' do
    it 'lists each needs-attention priority with explanation and primary action' do
      allow(OneOnOne::PriorityCarouselBuilder).to receive(:call).and_return(
        {
          priorities: [
            {
              needs_attention: true,
              title: 'First priority',
              reason: 'First explanation.',
              cta_kind: :bulk_goals,
              cta_label: 'Create goals'
            },
            {
              needs_attention: true,
              title: 'Second priority',
              reason: 'Second explanation.',
              cta_kind: :my_growth_goals,
              cta_label: 'Grow by goals'
            }
          ],
          needs_attention_count: 2,
          total_count: 13,
          first_attention_index: 0
        }
      )

      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.about_me_priorities_thread_payload

      expect(result[:text]).to include('First priority')
      expect(result[:text]).to include('First explanation.')
      expect(result[:text]).to include('Primary action:')
      expect(result[:text]).to include('Second priority')
      expect(result[:text]).to include('Second explanation.')
    end
  end

  describe '#thread2_about_me' do
    it 'uses absolute URLs in section detail links' do
      sections = [
        {
          key: :goals,
          status: :red,
          explanation_sentence: 'No active goals.'
        }
      ]
      allow(Digest::AboutMeContentService).to receive(:new).and_return(instance_double(Digest::AboutMeContentService, sections: sections))
      allow(GetShitDoneQueryService).to receive(:new).and_return(instance_double(GetShitDoneQueryService, all_pending_items: { total_pending: 0 }))

      builder = described_class.new(teammate: teammate, organization: organization)
      text = builder.thread2_about_me[:text]

      expect(text).to match(/<https?:\/\/[^|]+\|Active Goals>/)
      expect(text).not_to match(/<\/organizations/)
    end

    it 'returns detailed section content without weekly summary sentence' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.thread2_about_me

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      expect(result[:text]).to include('NEEDS MOST ATTENTION').or include('NEEDS SOME ATTENTION').or include('HEALTHY')
      expect(result[:text]).not_to include('It is time for our weekly check-in.')
    end
  end

  describe '#short_summary_for_sms' do
    it 'returns a plain string suitable for SMS' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.short_summary_for_sms

      expect(result).to be_a(String)
      expect(result).not_to include('*')
    end

    it 'uses company label for get_shit_done in the summary' do
      create(:company_label_preference, company: organization.root_company || organization, label_key: 'get_shit_done', label_value: 'My List')
      # Stub so we get the "all clear" branch which includes the GSD label
      gsd_items = { total_pending: 0, observable_moments: [], maap_snapshots: [], observation_drafts: [], goals_needing_check_in: [], check_ins_awaiting_input: [] }
      allow(GetShitDoneQueryService).to receive(:new).and_return(instance_double(GetShitDoneQueryService, all_pending_items: gsd_items))
      allow(Digest::AboutMeContentService).to receive(:new).and_return(instance_double(Digest::AboutMeContentService, sections: []))
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.short_summary_for_sms

      expect(result).to include('My List')
    end
  end
end
