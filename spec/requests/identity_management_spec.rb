require 'rails_helper'

RSpec.describe 'Identity Management', type: :request do
  let(:company) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:person) { create(:person) }
  let(:google_identity) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com') }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /profile' do
    it 'shows connected accounts section' do
      get profile_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Identities')
    end
  end

  describe 'POST /profile/identities/connect_google' do
    it 'redirects to Google OAuth' do
      post connect_google_identity_path
      expect(response).to redirect_to('/auth/google_oauth2')
    end
  end

  describe 'DELETE /profile/identities/:id' do
    context 'when user has multiple Google accounts' do
      before do
        @identity1 = create(:person_identity, person: person, provider: 'google_oauth2', email: 'test1@gmail.com')
        @identity2 = create(:person_identity, person: person, provider: 'google_oauth2', email: 'test2@gmail.com')
      end

    end

    context 'when user has only one Google account' do
      before do
        @identity = create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com')
      end

    end
  end
end
