# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::CompanyTeammates::Zoom::OauthController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, :employment_manager, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate(person, organization)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ZOOM_CLIENT_ID").and_return("zoom-client-id")
    allow(ENV).to receive(:[]).with("ZOOM_CLIENT_SECRET").and_return("zoom-client-secret")
  end

  describe "GET #authorize" do
    it "redirects to Zoom OAuth authorize" do
      get :authorize, params: {
        organization_id: organization.id,
        company_teammate_id: teammate.id,
        source: "consultOg",
        return_to: new_organization_possible_observation_consult_path(organization)
      }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("zoom.us/oauth/authorize")
      expect(response.location).to include("client_id=zoom-client-id")
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
          "access_token" => "zoom-access",
          "refresh_token" => "zoom-refresh",
          "expires_in" => 3600,
          "scope" => "cloud_recording:read:list_user_recordings"
        }.to_json
      )
      allow(HTTP).to receive(:basic_auth).and_return(instance_double(HTTP::Client, post: token_response))

      user_response = instance_double(
        HTTP::Response,
        body: {
          "id" => "zoom-user-123",
          "email" => "zoom@example.com",
          "first_name" => "Zoom",
          "last_name" => "User",
          "pic_url" => "https://example.com/pic.jpg"
        }.to_json
      )
      allow(HTTP).to receive(:auth).and_return(instance_double(HTTP::Client, get: user_response))
    end

    it "creates a zoom TeammateIdentity and redirects to return_to" do
      expect do
        get :callback, params: { code: "auth-code", state: state }
      end.to change { teammate.teammate_identities.zoom.count }.by(1)

      identity = teammate.reload.zoom_identity
      expect(identity.uid).to eq("zoom-user-123")
      expect(identity.raw_credentials["token"]).to eq("zoom-access")
      expect(response).to redirect_to(new_organization_possible_observation_consult_path(organization))
    end
  end

  describe "DELETE #disconnect" do
    before { create(:teammate_identity, :zoom, teammate: teammate) }

    it "destroys the zoom identity" do
      expect do
        delete :disconnect, params: {
          organization_id: organization.id,
          company_teammate_id: teammate.id
        }
      end.to change { teammate.teammate_identities.zoom.count }.from(1).to(0)
    end
  end
end
