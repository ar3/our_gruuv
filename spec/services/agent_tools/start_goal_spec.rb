# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::StartGoal, type: :service do
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
    create(:goal, :draft, creator: teammate, owner: teammate, company: organization, title: "Draft to start")
  end
  let(:goal_path) { AgentTools::RecordPaths.goal_path(context, goal) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "starts a draft goal" do
    result = described_class.call(context: context, goal_path: goal_path)

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(goal.reload.started_at).to be_present
    expect(result.data[:started]).to be(true)
    expect(result.data[:status]).to eq("active")
  end

  it "starts and sets current-week confidence when provided" do
    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 75,
      confidence_reason: "Looking good"
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(goal.reload.started_at).to be_present
    check_in = goal.goal_check_ins.find_by!(check_in_week_start: Date.current.beginning_of_week(:monday))
    expect(check_in.confidence_percentage).to eq(75)
  end

  it "rejects an already started goal" do
    goal.update!(started_at: Time.current)

    result = described_class.call(context: context, goal_path: goal_path)

    expect(result.ok?).to be(false)
    expect(result.error).to include("already started")
  end
end
