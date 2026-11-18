# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::AdvanceProgressiveAim, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:goal) do
    create(
      :goal,
      :active,
      creator: teammate,
      owner: teammate,
      company: organization,
      goal_type: "progressive_outcome",
      title: "Move retention from 50% to [60|70|80]%",
      outcome_baseline: 50,
      outcome_commit: 60,
      outcome_stretch: 70,
      outcome_transform: 80,
      outcome_unit: "%",
      progressive_current_aim: "commit",
      most_likely_target_date: Date.today + 90.days
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "completes the current aim and creates the next progressive goal" do
    result = described_class.call(
      goal: goal,
      current_person: person,
      current_teammate: teammate
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(goal.reload.completed_at).to be_present
    next_goal = result.next_goal
    expect(next_goal).to be_persisted
    expect(next_goal.progressive_current_aim).to eq("stretch")
    expect(next_goal.title).to include("70")
    expect(next_goal.linking_goals).to include(goal)
  end
end
