# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::CreateDraftGoal, type: :service do
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
  let(:owner_path) { AgentTools::RecordPaths.teammate_path(context, teammate) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "creates a draft goal owned by the teammate" do
    result = described_class.call(
      context: context,
      title: "Ship Goals MCP",
      owner_path: owner_path,
      description: "Phase 1"
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    goal = Goal.order(:id).last
    expect(goal.title).to eq("Ship Goals MCP")
    expect(goal.started_at).to be_nil
    expect(goal.status).to eq(:draft)
    expect(goal.owner).to eq(teammate)
    expect(result.data[:draft]).to be(true)
    expect(result.data[:needs_start]).to be(true)
    expect(result.data[:path]).to be_present
  end

  it "links optional parent goals" do
    parent = create(:goal, :draft, creator: teammate, owner: teammate, company: organization, title: "Parent")
    parent_path = AgentTools::RecordPaths.goal_path(context, parent)

    result = described_class.call(
      context: context,
      title: "Child",
      owner_path: owner_path,
      parent_goal_paths: [parent_path]
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    child = Goal.find_by!(title: "Child")
    expect(child.linking_goals).to include(parent)
    expect(result.data[:parent_paths]).to include(parent_path)
  end

  it "requires a title" do
    result = described_class.call(context: context, title: "  ", owner_path: owner_path)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
