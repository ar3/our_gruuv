# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyGrowth::OpenAssociatedGoalsByAssociable do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:other_assignment) { create(:assignment, company: organization) }

  def create_associated_goal(associable:, title:, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)
    goal = create(
      :goal,
      owner: teammate,
      creator: teammate,
      company_id: organization.id,
      title: title,
      started_at: started_at,
      completed_at: completed_at,
      deleted_at: deleted_at,
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil
    )
    create(:goal_association, goal: goal, associable: associable)
    goal
  end

  it "returns empty hash when associable ids are blank" do
    expect(
      described_class.call(teammate: teammate, associable_type: "Assignment", associable_ids: [])
    ).to eq({})
  end

  it "returns open goals with latest confidence for each associable" do
    open_goal = create_associated_goal(associable: assignment, title: "Ship onboarding")
    create_associated_goal(associable: assignment, title: "Done goal", completed_at: 1.day.ago)
    create_associated_goal(associable: other_assignment, title: "Other open")

    older = create(
      :goal_check_in,
      goal: open_goal,
      confidence_percentage: 40,
      check_in_week_start: 2.weeks.ago.beginning_of_week(:monday)
    )
    newer = create(
      :goal_check_in,
      goal: open_goal,
      confidence_percentage: 75,
      check_in_week_start: Date.current.beginning_of_week(:monday)
    )
    # Ensure "as of" uses saved time, not week start
    older.update_columns(created_at: 3.weeks.ago)
    newer.update_columns(created_at: 1.day.ago)

    result = described_class.call(
      teammate: teammate,
      associable_type: "Assignment",
      associable_ids: [assignment.id, other_assignment.id]
    )

    expect(result[assignment.id][:open_associated_goals_count]).to eq(1)
    row = result[assignment.id][:open_associated_goals].sole
    expect(row[:title]).to eq("Ship onboarding")
    expect(row[:confidence_percentage]).to eq(75)
    expect(row[:confidence_saved_at]).to be_within(1.second).of(1.day.ago)

    expect(result[other_assignment.id][:open_associated_goals_count]).to eq(1)
    other_row = result[other_assignment.id][:open_associated_goals].sole
    expect(other_row[:title]).to eq("Other open")
    expect(other_row[:confidence_percentage]).to be_nil
    expect(other_row[:confidence_saved_at]).to be_nil
  end

  it "sorts open goals by title" do
    create_associated_goal(associable: assignment, title: "Zebra")
    create_associated_goal(associable: assignment, title: "Alpha")

    result = described_class.call(
      teammate: teammate,
      associable_type: "Assignment",
      associable_ids: [assignment.id]
    )

    expect(result[assignment.id][:open_associated_goals].map { |g| g[:title] }).to eq(%w[Alpha Zebra])
  end

  it "excludes draft goals when active_only is true" do
    create_associated_goal(associable: assignment, title: "Active", started_at: 1.day.ago)
    create_associated_goal(associable: assignment, title: "Draft", started_at: nil)

    result = described_class.call(
      teammate: teammate,
      associable_type: "Assignment",
      associable_ids: [assignment.id],
      active_only: true
    )

    expect(result[assignment.id][:open_associated_goals_count]).to eq(1)
    expect(result[assignment.id][:open_associated_goals].map { |g| g[:title] }).to eq(["Active"])
  end
end
