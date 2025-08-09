require 'rails_helper'

RSpec.describe 'Identity Management', type: :request do
  let(:person) { create(:person) }
  let(:google_identity) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
  end

  describe 'GET /profile' do
    it 'shows connected accounts section' do
      get profile_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Connected Accounts')
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
      let!(:identity1) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test1@gmail.com') }
      let!(:identity2) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test2@gmail.com') }

      it 'allows disconnecting an identity' do
        delete disconnect_identity_path(identity1)
        expect(response).to redirect_to(profile_path)
        expect(flash[:notice]).to include('disconnected successfully')
      end
    end

    context 'when user has only one Google account' do
      let!(:identity) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com') }

      it 'prevents disconnecting the last Google account' do
        delete disconnect_identity_path(identity)
        expect(response).to redirect_to(profile_path)
        expect(flash[:alert]).to include('Cannot disconnect this account')
      end
    end
  end
end
