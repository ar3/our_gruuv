# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionChange::KeystoneEligibilityConversation do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, first_name: "Morgan", last_name: "Manager") }
  let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization) }
  let(:employee_person) { create(:person, first_name: "Alex", last_name: "Employee") }
  let(:teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let!(:employment) do
    create(
      :employment_tenure,
      teammate: teammate,
      company: organization,
      manager_teammate: manager_teammate,
      started_at: 1.year.ago,
      ended_at: nil
    )
  end
  let(:current_position) { employment.position }
  let(:target_position) { current_position }
  let(:assignment) { create(:assignment, company: organization, title: "Lead Delivery") }
  let(:ability) { create(:ability, company: organization, name: "Systems Thinking") }

  def call_service(target: target_position, eligible: false, eligibility_report: nil)
    if eligibility_report
      described_class.call(
        teammate: teammate,
        target_position: target,
        eligibility_report: eligibility_report
      )
    else
      described_class.call(
        teammate: teammate,
        target_position: target,
        target_eligible: eligible
      )
    end
  end

  def exceed_only_eligibility_report(assignment_title: "Lead Delivery")
    {
      overall_eligible: false,
      checks: [
        {
          key: :milestone_requirements,
          status: :passed,
          details: {}
        },
        {
          key: :required_assignment_check_in_requirements,
          status: :failed,
          details: {
            minimum_percentage_meeting: 80.0,
            minimum_percentage_exceeding: 40.0,
            qualifying_percentage_meeting: 100.0,
            qualifying_percentage_exceeding: 0.0
          }
        }
      ]
    }
  end

  def create_owned_goal(attrs = {})
    create(
      :goal,
      {
        creator: teammate,
        owner: teammate,
        company_id: organization.id,
        title: "Keystone goal",
        started_at: 1.week.ago,
        completed_at: nil,
        most_likely_target_date: Date.new(2026, 11, 15)
      }.merge(attrs)
    )
  end

  describe "prompt when target equals current and eligible" do
    it "suggests choosing a different target position" do
      result = call_service(eligible: true)

      expect(result.prompt_kind).to eq(described_class::PROMPT_SUGGEST_DIFFERENT_TARGET)
      expect(result.employee_casual_name).to include("Alex")
      expect(result.manager_casual_name).to include("Morgan")
    end
  end

  describe "blocking required assignment gaps" do
    before do
      create(:position_assignment, position: target_position, assignment: assignment, assignment_type: "required")
    end

    it "lists uncovered required assignments and uses incomplete_path" do
      result = call_service

      expect(result.prompt_kind).to eq(described_class::PROMPT_INCOMPLETE_PATH)
      expect(result.conversation_date).to be_nil
      expect(result.uncovered_blocking_gaps.map(&:label)).to eq(["Lead Delivery"])
      expect(result.keystone_goals).to be_empty
      expect(result.path_rows.map(&:object_label)).to eq(["Lead Delivery"])
      expect(result.path_rows.first.goal_status).to eq(:none)
    end

    it "does not treat meeting/exceeding required assignments as blocking" do
      create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment,
        official_rating: "meeting"
      )

      result = call_service

      expect(result.uncovered_blocking_gaps).to be_empty
      expect(result.prompt_kind).to eq(described_class::PROMPT_READY_NOW)
    end

    it "schedules conversation from incomplete keystone most_likely dates" do
      earlier = create_owned_goal(title: "Earlier", most_likely_target_date: Date.new(2026, 10, 1))
      later = create_owned_goal(title: "Later", most_likely_target_date: Date.new(2026, 12, 1))
      create(:goal_association, goal: earlier, associable: assignment)
      create(:goal_association, goal: later, associable: assignment)

      result = call_service

      expect(result.uncovered_blocking_gaps).to be_empty
      expect(result.keystone_goals.map(&:title)).to match_array(%w[Earlier Later])
      expect(result.conversation_date).to eq(Date.new(2026, 12, 1))
      expect(result.prompt_kind).to eq(described_class::PROMPT_SCHEDULED)
    end

    it "returns no date when an incomplete keystone lacks most_likely_target_date" do
      goal = create_owned_goal(
        title: "Undated",
        most_likely_target_date: nil,
        earliest_target_date: nil,
        latest_target_date: nil
      )
      create(:goal_association, goal: goal, associable: assignment)

      result = call_service

      expect(result.conversation_date).to be_nil
      expect(result.prompt_kind).to eq(described_class::PROMPT_INCOMPLETE_PATH)
    end

    it "includes completed keystones and is ready_now when only completed goals remain" do
      completed = create_owned_goal(
        title: "Done",
        completed_at: 1.day.ago,
        most_likely_target_date: Date.new(2026, 6, 1)
      )
      create(:goal_association, goal: completed, associable: assignment)

      result = call_service

      expect(result.keystone_goals.map(&:title)).to eq(["Done"])
      expect(result.conversation_date).to be_nil
      expect(result.prompt_kind).to eq(described_class::PROMPT_READY_NOW)
      expect(result.path_rows.size).to eq(1)
      expect(result.path_rows.first.goal_status).to eq(:completed)
      expect(result.path_rows.first.goal).to eq(completed)
    end
  end

  describe "ability milestone gaps" do
    before do
      create(:position_ability, position: target_position, ability: ability, milestone_level: 3)
    end

    it "lists uncovered ability gaps" do
      result = call_service

      expect(result.uncovered_blocking_gaps.map(&:kind)).to eq([:ability_milestone])
      expect(result.uncovered_blocking_gaps.first.label).to eq("Systems Thinking")
    end

    it "covers ability gaps with an ability-linked keystone goal" do
      goal = create_owned_goal(title: "Earn milestone 3")
      create(:goal_association, goal: goal, associable: ability)

      result = call_service

      expect(result.uncovered_blocking_gaps).to be_empty
      expect(result.keystone_goals.map(&:title)).to eq(["Earn milestone 3"])
      expect(result.prompt_kind).to eq(described_class::PROMPT_SCHEDULED)
    end
  end

  describe "WTM-linked keystones" do
    let(:wtm_assignment) { create(:assignment, company: organization, title: "WTM Work") }

    it "includes goals linked to working-to-meet assignments" do
      create(
        :assignment_check_in,
        :officially_completed,
        :working_to_meet,
        teammate: teammate,
        assignment: wtm_assignment
      )
      goal = create_owned_goal(title: "Close WTM")
      create(:goal_association, goal: goal, associable: wtm_assignment)

      result = call_service

      expect(result.keystone_goals.map(&:title)).to eq(["Close WTM"])
    end
  end

  describe "when eligibility only fails exceeding thresholds" do
    before do
      create(:position_assignment, position: target_position, assignment: assignment, assignment_type: "required")
      create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment,
        official_rating: "meeting"
      )
    end

    it "suppresses the conversation date and asks for exceed goals" do
      goal = create_owned_goal(title: "Already meeting path", most_likely_target_date: Date.new(2026, 12, 1))
      create(:goal_association, goal: goal, associable: assignment)

      result = call_service(eligibility_report: exceed_only_eligibility_report)

      expect(result.conversation_date).to be_nil
      expect(result.prompt_kind).to eq(described_class::PROMPT_NEEDS_EXCEED_GOALS)
      expect(result.path_rows.map(&:object_label)).to include("Lead Delivery")
      expect(result.path_rows.find { |r| r.object_label == "Lead Delivery" }.reason).to eq(
        described_class::EXCEED_REASON
      )
    end

    it "lists meeting-rated assignments without goals as exceed path rows" do
      result = call_service(eligibility_report: exceed_only_eligibility_report)

      row = result.path_rows.find { |r| r.object_label == "Lead Delivery" }
      expect(row).to be_present
      expect(row.goal_status).to eq(:none)
      expect(row.reason).to eq(described_class::EXCEED_REASON)
      expect(result.prompt_kind).to eq(described_class::PROMPT_NEEDS_EXCEED_GOALS)
    end
  end
end
