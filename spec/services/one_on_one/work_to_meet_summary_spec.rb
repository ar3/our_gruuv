# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneOnOne::WorkToMeetSummary do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  def call_summary(viewing_person: nil)
    described_class.call(organization: organization, teammate: teammate, viewing_person: viewing_person)
  end

  describe "tab badge" do
    it "is success with zero when there are no essential WTM areas" do
      summary = call_summary

      expect(summary.tab_variant).to eq(:success)
      expect(summary.tab_count).to eq(0)
    end

    it "is danger with the count of essential WTM areas missing an active goal" do
      assignment = create(:assignment, company: organization, title: "Essential WTM")
      create(:assignment_tenure, teammate: teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: assignment)

      aspiration = create(:aspiration, company: organization, name: "Value WTM")
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        employee_rating: "working_to_meet",
        manager_rating: "working_to_meet",
        official_rating: "working_to_meet"
      )

      summary = call_summary

      expect(summary.tab_variant).to eq(:danger)
      expect(summary.tab_count).to eq(2)
    end

    it "is info with the total essential WTM count when all have active goals" do
      assignment = create(:assignment, company: organization, title: "Covered WTM")
      create(:assignment_tenure, teammate: teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: assignment)
      goal = create(:goal, owner: teammate, creator: teammate, company_id: organization.id, started_at: 1.week.ago)
      create(:goal_association, goal: goal, associable: assignment)

      summary = call_summary

      expect(summary.tab_variant).to eq(:info)
      expect(summary.tab_count).to eq(1)
      expect(summary.essential_assignment_rows.first.has_active_goal).to be(true)
    end

    it "does not count draft-only goals toward active coverage" do
      assignment = create(:assignment, company: organization, title: "Draft only")
      create(:assignment_tenure, teammate: teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: assignment)
      draft_goal = create(:goal, owner: teammate, creator: teammate, company_id: organization.id, started_at: nil)
      create(:goal_association, goal: draft_goal, associable: assignment)

      summary = call_summary

      expect(summary.tab_variant).to eq(:danger)
      expect(summary.tab_count).to eq(1)
      expect(summary.essential_assignment_rows.first.draft_goal_count).to eq(1)
      expect(summary.essential_assignment_rows.first.has_active_goal).to be(false)
    end
  end

  describe "assignment essentiality" do
    it "puts non-essential WTM assignments in the non-essential list only" do
      essential = create(:assignment, company: organization, title: "Essential")
      create(:assignment_tenure, teammate: teammate, assignment: essential)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: essential)

      non_essential = create(:assignment, company: organization, title: "Extra")
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: non_essential)

      summary = call_summary

      expect(summary.essential_assignment_rows.map { |r| r.associable }).to eq([essential])
      expect(summary.non_essential_assignment_rows.map { |r| r.associable }).to eq([non_essential])
      expect(summary.tab_count).to eq(1)
    end
  end

  describe "aspiration rows" do
    it "uses the most recent finalized check-in when multiple exist" do
      aspiration = create(:aspiration, company: organization, name: "Growth Mindset")
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: 6.months.ago,
        employee_rating: "meeting",
        manager_rating: "meeting",
        official_rating: "meeting"
      )
      create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: 1.week.ago,
        employee_rating: "working_to_meet",
        manager_rating: "working_to_meet",
        official_rating: "working_to_meet"
      )

      summary = call_summary(viewing_person: nil)

      expect(summary.essential_aspiration_rows.map { |row| row.associable }).to eq([aspiration])
      expect(summary.essential_aspiration_rows.first.check_in.official_rating).to eq("working_to_meet")
    end
  end

  describe "OGO counts" do
    it "counts published OGOs visible to the viewing person where the teammate is observed and the object is rated" do
      assignment = create(:assignment, company: organization, title: "Rated Assignment")
      create(:assignment_tenure, teammate: teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: assignment)

      observer = create(:person)
      observation = create(:observation, company: organization, observer: observer, published_at: Time.current)
      observation.observees.destroy_all
      create(:observee, observation: observation, company_teammate: teammate)
      create(:observation_rating, observation: observation, rateable: assignment)

      summary = call_summary(viewing_person: observer)

      expect(summary.essential_assignment_rows.first.ogo_count).to eq(1)
    end

    it "excludes OGOs the viewing person cannot see" do
      assignment = create(:assignment, company: organization, title: "Private Rated Assignment")
      create(:assignment_tenure, teammate: teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: teammate, assignment: assignment)

      other_observer = create(:person)
      other_teammate = create(:teammate, organization: organization, person: other_observer)
      observation = create(
        :observation,
        company: organization,
        observer: other_observer,
        published_at: Time.current,
        privacy_level: :observed_only
      )
      observation.observees.destroy_all
      create(:observee, observation: observation, company_teammate: teammate)
      create(:observation_rating, observation: observation, rateable: assignment)

      unrelated_viewer = create(:person)
      create(:teammate, organization: organization, person: unrelated_viewer)

      summary = call_summary(viewing_person: unrelated_viewer)

      expect(summary.essential_assignment_rows.first.ogo_count).to eq(0)
    end
  end
end
