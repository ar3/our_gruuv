# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::CompanyTeammates::SlackSearch::OauthController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:other_person) { create(:person) }
  let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    other_teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate(person, organization)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SLACK_CLIENT_ID").and_return("slack-client-id")
    allow(ENV).to receive(:[]).with("SLACK_CLIENT_SECRET").and_return("slack-client-secret")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("SLACK_SEARCH_USER_SCOPE", "search:read").and_return("search:read")
  end

  describe "GET #authorize" do
    it "redirects to Slack OAuth with user_scope for the current teammate" do
      get :authorize, params: {
        organization_id: organization.id,
        company_teammate_id: teammate.id,
        source: "sourceFromSlack"
      }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("slack.com/oauth/v2/authorize")
      expect(response.location).to include("user_scope=")
      expect(response.location).to include("search")
      expect(response.location).to include("sourceFromSlack")
    end

    it "does not allow connecting Slack search for another teammate" do
      get :authorize, params: {
        organization_id: organization.id,
        company_teammate_id: other_teammate.id
      }

      expect(response).to redirect_to(organization_company_teammate_path(organization, other_teammate))
      expect(flash[:alert]).to include("yourself")
    end
  end

  describe "GET #callback" do
    let(:oauth_code) { "test_oauth_code" }
    let(:access_token) { "xoxp-test-token" }
    let(:slack_user_id) { "USEARCH999" }
    let(:state) { "#{organization.id}_#{teammate.id}_identities" }

    before do
      token_response = double(
        body: double(
          to_s: {
            "ok" => true,
            "team" => { "id" => "T123", "name" => "Acme" },
            "authed_user" => {
              "id" => slack_user_id,
              "access_token" => access_token,
              "scope" => "search:read",
              "token_type" => "user"
            }
          }.to_json
        )
      )
      allow(HTTP).to receive(:post).and_return(token_response)

      auth_response = double(
        body: double(to_s: { "ok" => true, "user" => "searchuser", "user_id" => slack_user_id }.to_json)
      )
      user_response = double(
        body: double(
          to_s: {
            "ok" => true,
            "user" => {
              "id" => slack_user_id,
              "real_name" => "Search User",
              "profile" => {
                "email" => "search@example.com",
                "image_72" => "https://example.com/avatar.jpg"
              }
            }
          }.to_json
        )
      )
      allow(HTTP).to receive(:get).and_return(auth_response, user_response)
    end

    it "creates a slack_search identity with user token credentials" do
      expect {
        get :callback, params: { code: oauth_code, state: state }
      }.to change(TeammateIdentity, :count).by(1)

      identity = teammate.reload.slack_search_identity
      expect(identity).to be_present
      expect(identity.provider).to eq("slack_search")
      expect(identity.uid).to eq(slack_user_id)
      expect(identity.email).to eq("search@example.com")
      expect(identity.name).to eq("Search User")
      expect(identity.raw_credentials["token"]).to eq(access_token)
      expect(identity.raw_credentials["scope"]).to eq("search:read")
    end

    it "does not overwrite an existing linked Slack identity" do
      linked = create(:teammate_identity, :slack, teammate: teammate, uid: "ULINKED1")

      get :callback, params: { code: oauth_code, state: state }

      expect(teammate.reload.slack_identity).to eq(linked)
      expect(teammate.slack_search_identity).to be_present
      expect(teammate.slack_search_identity.uid).to eq(slack_user_id)
    end

    it "redirects to the source tab when source is sourceFromSlack" do
      source_state = "#{organization.id}_#{teammate.id}_sourceFromSlack"
      get :callback, params: { code: oauth_code, state: source_state }

      expect(response).to redirect_to(ogos_source_from_slack_organization_company_teammate_path(organization, teammate))
      expect(flash[:notice]).to include("Slack (search) connected")
    end
  end

  describe "DELETE #disconnect" do
    let!(:identity) { create(:teammate_identity, :slack_search, teammate: teammate) }

    it "destroys the slack_search identity" do
      expect {
        delete :disconnect, params: { organization_id: organization.id, company_teammate_id: teammate.id }
      }.to change(TeammateIdentity, :count).by(-1)

      expect(teammate.reload.slack_search_identity).to be_nil
      expect(flash[:notice]).to include("disconnected")
    end

    it "does not allow disconnecting another teammate's identity" do
      create(:teammate_identity, :slack_search, teammate: other_teammate)

      delete :disconnect, params: { organization_id: organization.id, company_teammate_id: other_teammate.id }

      expect(response).to redirect_to(organization_company_teammate_path(organization, other_teammate))
      expect(other_teammate.reload.slack_search_identity).to be_present
    end
  end
end
