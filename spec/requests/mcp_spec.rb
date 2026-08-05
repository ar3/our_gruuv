# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP HTTP endpoint", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:token_record) do
    create(:mcp_access_token, company_teammate: teammate)
  end
  let(:raw_token) { token_record.raw_token_for_specs }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  def mcp_post(body, token: raw_token)
    post "/mcp",
         params: body.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json",
           "AUTHORIZATION" => "Bearer #{token}"
         }
  end

  it "rejects missing auth" do
    post "/mcp", params: { jsonrpc: "2.0", method: "ping", id: 1 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "initializes and lists AgentTools via tools/list" do
    mcp_post({ jsonrpc: "2.0", method: "initialize", id: 1, params: {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "rspec", version: "1.0" }
    } })
    expect(response).to have_http_status(:ok).or have_http_status(:accepted)

    mcp_post({ jsonrpc: "2.0", method: "tools/list", id: 2, params: {} })
    expect(response).to have_http_status(:ok).or have_http_status(:accepted)

    payload = JSON.parse(response.body)
    names = payload.dig("result", "tools")&.map { |t| t["name"] } || []
    expect(names).to include(
      "list_teammates",
      "list_goals",
      "list_assignments",
      "list_abilities",
      "list_sitemap",
      "list_observations",
      "search_organization",
      "create_draft_observation",
      "set_current_week_goal_confidence"
    )
  end

  it "invokes list_teammates through tools/call" do
    mcp_post({ jsonrpc: "2.0", method: "tools/call", id: 3, params: {
      name: "list_teammates",
      arguments: { limit: 5 }
    } })

    expect(response).to have_http_status(:ok).or have_http_status(:accepted)
    payload = JSON.parse(response.body)
    text = payload.dig("result", "content", 0, "text")
    expect(text).to be_present
    inner = JSON.parse(text)
    expect(inner["ok"]).to be(true)
    expect(inner["data"]).to have_key("teammates")
  end
end
