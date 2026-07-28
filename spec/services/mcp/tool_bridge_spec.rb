# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mcp::ToolBridge, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:observee) { create(:teammate, organization: organization) }
  let(:context) do
    Assistant::ContextBuilder.call(organization: organization, company_teammate: teammate)
  end
  let(:observee_path) { AgentTools::RecordPaths.teammate_path(context, observee) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: observee, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "creates draft OGOs with mcp provenance" do
    response = described_class.call(
      tool_name: "create_draft_observation",
      context: context,
      observee_path: observee_path,
      story: "From MCP",
      trigger_source: "ask_og"
    )

    expect(response.error?).to be(false)
    observation = Observation.order(:id).last
    expect(observation.published_at).to be_nil
    expect(observation.observation_trigger.trigger_source).to eq("mcp")
    expect(observation.created_as_type).to eq("mcp")
  end

  it "returns error_code on validation failure" do
    response = described_class.call(
      tool_name: "set_current_week_goal_confidence",
      context: context,
      goal_path: "/organizations/#{organization.id}/goals/999999",
      confidence_percentage: 50
    )

    expect(response.error?).to be(true)
    payload = JSON.parse(response.content.first[:text])
    expect(payload["ok"]).to be(false)
    expect(payload["error_code"]).to be_present
  end
end
