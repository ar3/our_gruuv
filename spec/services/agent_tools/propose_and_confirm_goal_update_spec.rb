# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AgentTools goal update propose/confirm", type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate,
      mutation_gate: :tool_pending
    )
  end
  let(:goal) do
    create(:goal, :active, creator: teammate, owner: teammate, company: organization, title: "Original")
  end
  let(:goal_path) { AgentTools::RecordPaths.goal_path(context, goal) }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    allow(Rails).to receive(:cache).and_return(memory_cache)
  end

  it "does not persist until confirm_goal_change" do
    proposed = AgentTools::ProposeGoalUpdate.call(
      context: context,
      goal_path: goal_path,
      title: "Renamed"
    )

    expect(proposed.ok?).to be(true), -> { proposed.error.inspect }
    expect(proposed.data[:needs_confirmation]).to be(true)
    expect(proposed.data[:change_token]).to be_present
    expect(goal.reload.title).to eq("Original")

    confirmed = AgentTools::ConfirmGoalChange.call(
      context: context,
      change_token: proposed.data[:change_token]
    )

    expect(confirmed.ok?).to be(true), -> { confirmed.error.inspect }
    expect(goal.reload.title).to eq("Renamed")
  end

  it "adds parent links on confirm" do
    parent = create(:goal, :active, creator: teammate, owner: teammate, company: organization, title: "Parent")
    parent_path = AgentTools::RecordPaths.goal_path(context, parent)

    proposed = AgentTools::ProposeGoalUpdate.call(
      context: context,
      goal_path: goal_path,
      add_parent_paths: [parent_path]
    )
    expect(proposed.ok?).to be(true), -> { proposed.error.inspect }

    confirmed = AgentTools::ConfirmGoalChange.call(
      context: context,
      change_token: proposed.data[:change_token]
    )
    expect(confirmed.ok?).to be(true), -> { confirmed.error.inspect }
    expect(goal.reload.linking_goals).to include(parent)
  end

  it "rejects an invalid or expired change_token" do
    result = AgentTools::ConfirmGoalChange.call(context: context, change_token: "nope")
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
