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

  describe '#thread2_about_me' do
    it 'returns hash with :blocks and :text with healthy/attention summary and section links' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.thread2_about_me

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      # New format: "<x> sections are healthy, <y> need some attention, <z> need the most attention."
      expect(result[:text]).to match(/section.*healthy|attention|most attention/i)
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
