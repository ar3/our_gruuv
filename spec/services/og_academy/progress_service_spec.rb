# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgAcademy::ProgressService do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  subject(:service) { described_class.new(organization: company, company_teammate: teammate) }

  describe '#levels' do
    it 'returns five levels with reshaped criteria keys' do
      expect {
        levels = service.levels
        expect(levels.map(&:level)).to eq([1, 2, 3, 4, 5])
        expect(levels[0].criteria.map(&:key)).to eq(%i[logged_in check_in_types published_ogo added_goal])
        expect(levels[1].criteria.map(&:key)).to eq(%i[
          real_milestone confidence_checks notifications visited_my_growth visited_my_one_thing
          sent_feedback_request
        ])
        expect(levels[2].audience).to eq(:everyone)
        expect(levels[2].criteria.map(&:key)).to include(
          :check_in_depth, :visited_teammates_index, :visited_teammate_internals,
          :responded_to_feedback_request, :linked_goals, :observe_three, :four_ratings, :maap_comment
        )
        expect(levels[2].criteria.map(&:key)).not_to include(:visited_my_growth, :visited_my_one_thing)
        expect(levels[3].criteria.map(&:key)).to eq(%i[maap_edits employment_stewardship visited_insights_and_billing])
        expect(levels.last.criteria.map(&:key)).to eq(%i[
          published_position_other_orgs
          published_assignment_other_orgs
          published_ability_other_orgs
        ])
        expect(levels.last.criteria.map(&:done)).to all(eq(false))
      }.not_to change(TeammateMilestone, :count)
    end

    it 'marks logged_in complete when viewing' do
      logged_in = service.levels[0].criteria.find { |c| c.key == :logged_in }
      expect(logged_in.done).to eq(true)
    end

    it 'marks published_ogo when the person has a published observation in company' do
      build(:observation,
            observer: person,
            company: company,
            privacy_level: :public_to_company,
            observed_at: 1.day.ago,
            published_at: 1.day.ago).tap do |obs|
        obs.observees.build(teammate: teammate)
        obs.save!
      end

      criterion = service.levels[0].criteria.find { |c| c.key == :published_ogo }
      expect(criterion.done).to eq(true)
    end

    it 'marks check_in_types when employee completed each type once' do
      create(:assignment_check_in, teammate: teammate, employee_completed_at: 1.day.ago)
      create(:position_check_in, teammate: teammate, employee_completed_at: 1.day.ago)
      create(:aspiration_check_in, teammate: teammate, employee_completed_at: 1.day.ago)

      criterion = service.levels[0].criteria.find { |c| c.key == :check_in_types }
      expect(criterion.done).to eq(true)
    end

    it 'marks visited_my_growth and visited_my_one_thing from PageVisit urls on M2' do
      create(
        :page_visit,
        person: person,
        url: "/organizations/#{company.to_param}/company_teammates/me/my_growth/abilities",
        page_title: 'My Growth',
        visited_at: Time.current
      )
      create(
        :page_visit,
        person: person,
        url: "/organizations/#{company.to_param}/company_teammates/me/one_on_one_link",
        page_title: 'One Thing',
        visited_at: Time.current
      )

      levels = service.levels
      expect(levels[1].criteria.find { |c| c.key == :visited_my_growth }.done).to eq(true)
      expect(levels[1].criteria.find { |c| c.key == :visited_my_one_thing }.done).to eq(true)
    end

    it 'counts own-hub visits when the teammate id is negative' do
      allow(teammate).to receive(:id).and_return(-1)
      service = described_class.new(organization: company, company_teammate: teammate)

      create(
        :page_visit,
        person: person,
        url: "/organizations/#{company.to_param}/company_teammates/-1/my_growth/goals",
        page_title: 'My Growth',
        visited_at: Time.current
      )
      create(
        :page_visit,
        person: person,
        url: "/organizations/#{company.to_param}/company_teammates/-1/one_on_one_link",
        page_title: 'One Thing',
        visited_at: Time.current
      )

      levels = service.levels
      expect(levels[1].criteria.find { |c| c.key == :visited_my_growth }.done).to eq(true)
      expect(levels[1].criteria.find { |c| c.key == :visited_my_one_thing }.done).to eq(true)
    end

    it 'marks visited_teammates_index and teammate internals from PageVisit urls' do
      create(
        :page_visit,
        person: person,
        url: "/organizations/#{company.to_param}/employees?spotlight=teammate_tenures",
        page_title: 'Teammates',
        visited_at: 2.days.ago
      )

      other_teammates = create_list(:teammate, 5, organization: company)
      other_teammates.each_with_index do |other, idx|
        create(
          :page_visit,
          person: person,
          url: "/organizations/#{company.to_param}/company_teammates/#{other.id}/internal",
          page_title: 'Internal',
          visited_at: (idx + 1).hours.ago
        )
      end
      # Own internal should not count
      create(
        :page_visit,
        person: person,
        url: "/organizations/#{company.to_param}/company_teammates/me/internal",
        page_title: 'Internal',
        visited_at: Time.current
      )

      levels = service.levels
      expect(levels[2].criteria.find { |c| c.key == :visited_teammates_index }.done).to eq(true)
      expect(levels[2].criteria.find { |c| c.key == :visited_teammate_internals }.done).to eq(true)
    end

    it 'marks visited_insights_and_billing when every insights page and billing were visited' do
      (OgAcademy::ProgressService::INSIGHT_PATH_SEGMENTS + ['value_billing']).each do |segment|
        create(
          :page_visit,
          person: person,
          url: "/organizations/#{company.to_param}/#{segment}",
          page_title: segment,
          visited_at: Time.current
        )
      end

      criterion = service.levels[3].criteria.find { |c| c.key == :visited_insights_and_billing }
      expect(criterion.done).to eq(true)
    end

    it 'marks linked_goals when assignment and ability associations exist' do
      assignment = create(:assignment, company: company)
      ability = create(:ability, company: company)
      goal_a = create(:goal, company: company, owner: teammate, creator: teammate)
      goal_b = create(:goal, company: company, owner: teammate, creator: teammate)
      create(:goal_association, goal: goal_a, associable: assignment)
      create(:goal_association, goal: goal_b, associable: ability)

      criterion = service.levels[2].criteria.find { |c| c.key == :linked_goals }
      expect(criterion.done).to eq(true)
    end

    it 'marks sent_feedback_request when the teammate is requestor of a feedback request' do
      subject_teammate = create(:teammate, organization: company)
      create(
        :feedback_request,
        company: company,
        requestor_teammate: teammate,
        subject_of_feedback_teammate: subject_teammate
      )

      criterion = service.levels[1].criteria.find { |c| c.key == :sent_feedback_request }
      expect(criterion.done).to eq(true)
    end

    it 'marks responded_to_feedback_request when a responder completion exists' do
      requestor = create(:teammate, organization: company)
      subject_teammate = create(:teammate, organization: company)
      feedback_request = create(
        :feedback_request,
        company: company,
        requestor_teammate: requestor,
        subject_of_feedback_teammate: subject_teammate
      )
      feedback_request.feedback_request_responders.create!(teammate: teammate, completed_at: 1.day.ago)

      criterion = service.levels[2].criteria.find { |c| c.key == :responded_to_feedback_request }
      expect(criterion.done).to eq(true)
    end

    it 'keeps M4+ in the level list for non-admins' do
      expect(service.admin_track?).to eq(false)
      expect(service.levels.map(&:level)).to eq([1, 2, 3, 4, 5])
      expect(service.visible_for?(service.levels[3])).to eq(false)
    end
  end
end
