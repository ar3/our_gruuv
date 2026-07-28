# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP OAuth discovery", type: :request do
  it "serves protected resource metadata" do
    get "/.well-known/oauth-protected-resource"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["resource"]).to include("/mcp")
    expect(body["authorization_servers"]).to be_present
    expect(body["scopes_supported"]).to include("mcp", "offline_access")
  end

  it "serves authorization server metadata with PKCE + DCR + CIMD" do
    get "/.well-known/oauth-authorization-server"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["code_challenge_methods_supported"]).to eq(["S256"])
    expect(body["token_endpoint_auth_methods_supported"]).to include("none")
    expect(body["client_id_metadata_document_supported"]).to eq(true)
    expect(body["registration_endpoint"]).to include("/oauth/mcp/register")
    expect(body["authorization_endpoint"]).to include("/oauth/mcp/authorize")
    expect(body["token_endpoint"]).to include("/oauth/mcp/token")
  end
end
