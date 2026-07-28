# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP OAuth flow", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:redirect_uri) { "https://claude.ai/api/mcp/auth_callback" }
  let(:code_verifier) { SecureRandom.urlsafe_base64(64) }
  let(:code_challenge) { McpOauth::Pkce.s256_challenge(code_verifier) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  def register_client
    post "/oauth/mcp/register",
         params: {
           client_name: "Claude",
           redirect_uris: [redirect_uri],
           token_endpoint_auth_method: "none",
           grant_types: %w[authorization_code refresh_token],
           response_types: %w[code]
         }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)
  end

  it "registers a public client via DCR" do
    body = register_client
    expect(body["client_id"]).to start_with("ogdcr_")
    expect(body["token_endpoint_auth_method"]).to eq("none")
  end

  it "issues tokens via authorize + PKCE code exchange and calls MCP tools" do
    client = register_client
    sign_in_as_teammate_for_request(person, organization)

    get "/oauth/mcp/authorize", params: {
      client_id: client["client_id"],
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "mcp offline_access",
      state: "xyz",
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Connect Claude")
    expect(response.body).to include("Organization")

    post "/oauth/mcp/authorize", params: {
      client_id: client["client_id"],
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "mcp offline_access",
      state: "xyz",
      code_challenge: code_challenge,
      code_challenge_method: "S256",
      company_teammate_id: teammate.id
    }
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(%r{\Ahttps://claude\.ai/api/mcp/auth_callback\?})
    location = response.headers["Location"]
    code = Rack::Utils.parse_query(URI.parse(location).query)["code"]
    expect(code).to be_present

    post "/oauth/mcp/token",
         params: {
           grant_type: "authorization_code",
           code: code,
           redirect_uri: redirect_uri,
           client_id: client["client_id"],
           code_verifier: code_verifier
         }
    expect(response).to have_http_status(:ok)
    tokens = JSON.parse(response.body)
    expect(tokens["access_token"]).to start_with("ogoat_")
    expect(tokens["refresh_token"]).to start_with("ogrt_")
    expect(tokens["token_type"]).to eq("Bearer")

    post "/mcp",
         params: {
           jsonrpc: "2.0",
           method: "tools/call",
           id: 1,
           params: { name: "list_teammates", arguments: { limit: 5 } }
         }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "AUTHORIZATION" => "Bearer #{tokens['access_token']}"
         }
    expect(response).to have_http_status(:ok).or have_http_status(:accepted)
    payload = JSON.parse(response.body)
    text = payload.dig("result", "content", 0, "text")
    expect(JSON.parse(text)["ok"]).to eq(true)
  end

  it "returns WWW-Authenticate resource_metadata on unauthenticated MCP" do
    post "/mcp",
         params: { jsonrpc: "2.0", method: "initialize", id: 1, params: {} }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to include("resource_metadata=")
    expect(response.headers["WWW-Authenticate"]).to include("oauth-protected-resource")
  end

  it "rotates refresh tokens" do
    client = register_client
    sign_in_as_teammate_for_request(person, organization)

    post "/oauth/mcp/authorize", params: {
      client_id: client["client_id"],
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "mcp offline_access",
      code_challenge: code_challenge,
      code_challenge_method: "S256",
      company_teammate_id: teammate.id
    }
    code = Rack::Utils.parse_query(URI.parse(response.headers["Location"]).query)["code"]

    post "/oauth/mcp/token", params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client["client_id"],
      code_verifier: code_verifier
    }
    first = JSON.parse(response.body)

    post "/oauth/mcp/token", params: {
      grant_type: "refresh_token",
      refresh_token: first["refresh_token"],
      client_id: client["client_id"]
    }
    expect(response).to have_http_status(:ok)
    second = JSON.parse(response.body)
    expect(second["access_token"]).to be_present
    expect(second["refresh_token"]).to be_present
    expect(second["refresh_token"]).not_to eq(first["refresh_token"])

    post "/oauth/mcp/token", params: {
      grant_type: "refresh_token",
      refresh_token: first["refresh_token"],
      client_id: client["client_id"]
    }
    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)["error"]).to eq("invalid_grant")
  end
end
