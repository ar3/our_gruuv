# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::CompanyTeammates::GoogleMeet::OauthController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, :employment_manager, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate(person, organization)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("google-client-id")
    allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("google-client-secret")
    allow(ENV).to receive(:fetch).and_call_original
  end

  describe "GET #authorize" do
    it "redirects to Google OAuth with offline access and Meet scopes" do
      get :authorize, params: {
        organization_id: organization.id,
        company_teammate_id: teammate.id,
        source: "consultOg",
        return_to: new_organization_possible_observation_consult_path(organization)
      }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("accounts.google.com/o/oauth2/v2/auth")
      expect(response.location).to include("access_type=offline")
      expect(response.location).to include("meetings.space.readonly")
      expect(response.location).to include("drive.meet.readonly")
      expect(response.location).to include("consultOg")
    end
  end

  describe "GET #callback" do
    let(:state) do
      return_url = Base64.urlsafe_encode64(new_organization_possible_observation_consult_path(organization))
      "#{organization.id}_#{teammate.id}_consultOg_#{return_url}"
    end

    before do
      token_response = instance_double(
        HTTP::Response,
        body: {
          "access_token" => "ya29.access",
          "refresh_token" => "1//refresh",
          "expires_in" => 3600,
          "scope" => "openid email profile https://www.googleapis.com/auth/meetings.space.readonly"
        }.to_json
      )
      allow(HTTP).to receive(:post).and_return(token_response)

      user_response = instance_double(
        HTTP::Response,
        body: {
          "sub" => "google-user-123",
          "email" => "meet@example.com",
          "name" => "Meet User",
          "picture" => "https://example.com/pic.jpg"
        }.to_json
      )
      allow(HTTP).to receive(:auth).and_return(instance_double(HTTP::Client, get: user_response))
    end

    it "creates a google_meet TeammateIdentity and redirects to return_to" do
      expect do
        get :callback, params: { code: "auth-code", state: state }
      end.to change { teammate.teammate_identities.google_meet.count }.by(1)

      identity = teammate.reload.google_meet_identity
      expect(identity.uid).to eq("google-user-123")
      expect(identity.raw_credentials["token"]).to eq("ya29.access")
      expect(identity.raw_credentials["refresh_token"]).to eq("1//refresh")
      expect(response).to redirect_to(new_organization_possible_observation_consult_path(organization))
    end
  end

  describe "DELETE #disconnect" do
    before do
      create(:teammate_identity, :google_meet, teammate: teammate)
    end

    it "destroys the google_meet identity" do
      expect do
        delete :disconnect, params: {
          organization_id: organization.id,
          company_teammate_id: teammate.id
        }
      end.to change { teammate.teammate_identities.google_meet.count }.from(1).to(0)
    end
  end
end
