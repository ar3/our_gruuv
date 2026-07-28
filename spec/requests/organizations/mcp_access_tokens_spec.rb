# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::McpAccessTokens", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  it "creates a token and shows the raw value once via flash" do
    expect {
      post organization_mcp_access_tokens_path(organization),
           params: { mcp_access_token: { name: "My Claude" } }
    }.to change(McpAccessToken, :count).by(1)

    expect(response).to redirect_to(organization_mcp_access_tokens_path(organization))
    follow_redirect!
    expect(response.body).to include("Copy this token now")
    expect(response.body).to include("ogmcp_")
  end
end
