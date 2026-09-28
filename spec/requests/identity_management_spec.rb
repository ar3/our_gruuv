require 'rails_helper'

RSpec.describe 'Identity Management', type: :request do
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:person) { create(:person) }
  let(:google_identity) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com') }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/people/:id' do
    let(:teammate) { person.teammates.find_by(organization: company) || create(:teammate, person: person, organization: company) }
    
    it 'shows connected accounts section' do
      get organization_company_teammate_path(company, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Identities')
    end

    context 'with person and teammate identities' do
      let(:teammate) { person.teammates.find_by(organization: company) || create(:teammate, person: person, organization: company) }
      let!(:google_identity) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com') }
      let!(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate, email: 'test@slack.com') }
      let!(:asana_identity) { create(:teammate_identity, :asana, teammate: teammate, email: 'test@asana.com') }

      it 'displays all identities in the table' do
        get organization_company_teammate_path(company, teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Google')
        expect(response.body).to include('Slack')
        expect(response.body).to include('Asana')
      end

      it 'shows view raw data button in actions column' do
        get organization_company_teammate_path(company, teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('View Raw Data')
      end

      it 'does not show Slack Integration section' do
        get organization_company_teammate_path(company, teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('Slack Integration')
      end

      it 'shows Connect Asana Account button when not connected' do
        asana_identity.destroy
        get organization_company_teammate_path(company, teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Connect Asana Account')
      end

      it 'does not show Connect Asana Account button when already connected' do
        get organization_company_teammate_path(company, teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('Connect Asana Account')
      end
    end
  end

  describe 'POST /profile/identities/connect_google' do
    it 'redirects to Google OAuth' do
      post connect_google_identity_path
      expect(response).to redirect_to('/auth/google_oauth2')
    end
  end

  describe 'DELETE /profile/identities/:id' do
    let(:teammate) { person.teammates.find_by(organization: company) }

    context 'when user has multiple Google accounts' do
      let!(:identity1) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test1@gmail.com') }
      let!(:identity2) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test2@gmail.com') }

      it 'disconnects the identity and redirects to the teammate identities page' do
        expect {
          delete disconnect_identity_path(identity1)
        }.to change { person.person_identities.count }.by(-1)

        expect(response).to redirect_to(organization_company_teammate_path(company, teammate))
        expect(flash[:notice]).to eq('Account disconnected successfully!')
      end
    end

    context 'when user has only one Google account' do
      let!(:identity) { create(:person_identity, person: person, provider: 'google_oauth2', email: 'test@gmail.com') }

      it 'does not disconnect and redirects with an alert' do
        expect {
          delete disconnect_identity_path(identity)
        }.not_to change { person.person_identities.count }

        expect(response).to redirect_to(organization_company_teammate_path(company, teammate))
        expect(flash[:alert]).to include('Cannot disconnect')
      end
    end
  end
end
