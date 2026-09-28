require 'rails_helper'

RSpec.describe "Auths", type: :request do
  describe "GET /auth/google_oauth2/callback" do
    it "redirects without auth data" do
      get "/auth/google_oauth2/callback"
      expect(response).to have_http_status(:redirect)
    end

    context "when already signed in and connecting an additional Google account" do
      let(:organization) { create(:organization, :company) }
      let(:person) { create(:person, email: "existing@example.com") }
      let!(:teammate) { sign_in_as_teammate_for_request(person, organization) }
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid: "google-uid-additional-#{SecureRandom.hex(4)}",
          info: OmniAuth::AuthHash::InfoHash.new(
            email: "additional@gmail.com",
            name: "Additional Google",
            first_name: "Additional",
            last_name: "Google",
            image: "https://example.com/avatar.png"
          ),
          credentials: OmniAuth::AuthHash.new(
            token: "token",
            refresh_token: "refresh",
            expires_at: 1.hour.from_now.to_i,
            expires: true
          ),
          extra: OmniAuth::AuthHash.new(raw_info: {})
        )
      end

      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:google_oauth2] = nil
      end

      it "creates the Google identity and redirects to the teammate identities page" do
        expect {
          get "/auth/google_oauth2/callback"
        }.to change { person.person_identities.where(provider: "google_oauth2").count }.by(1)

        expect(response).to redirect_to(organization_company_teammate_path(organization, teammate))
        expect(flash[:notice]).to eq("Google account connected successfully!")
      end
    end
  end
end
