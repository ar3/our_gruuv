# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::DigestController, type: :controller do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, organization: company, person: person) }

  before do
    sign_in_as_teammate(person, company)
  end

  describe 'GET #edit' do
    it 'renders the edit template' do
      get :edit, params: { organization_id: company.to_param }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it 'assigns user_preference, teammate, and return params' do
      get :edit, params: { organization_id: company.to_param }
      expect(assigns(:user_preference)).to eq(UserPreference.for_person(person))
      expect(assigns(:teammate)).to eq(teammate)
      expect(assigns(:return_url)).to be_nil
      expect(assigns(:return_text)).to be_nil
    end

    it 'passes return_url and return_text when provided' do
      get :edit, params: {
        organization_id: company.to_param,
        return_url: 'https://example.com/back',
        return_text: 'Back to GSD'
      }
      expect(assigns(:return_url)).to eq('https://example.com/back')
      expect(assigns(:return_text)).to eq('Back to GSD')
    end
  end

  describe 'PATCH #update' do
    it 'updates digest preferences and redirects to return_url when present (Save preferences button)' do
      return_url = organization_get_shit_done_path(company)
      patch :update, params: {
        organization_id: company.to_param,
        digest_slack: 'daily',
        digest_email: 'weekly',
        digest_sms: 'off',
        return_url: return_url,
        return_text: 'Back to list',
        commit: 'Save preferences'
      }
      expect(response).to redirect_to(return_url)
      expect(flash[:notice]).to eq('Digest preferences saved.')

      pref = UserPreference.for_person(person).reload
      expect(pref.preference(:digest_slack)).to eq('daily')
      expect(pref.preference(:digest_email)).to eq('weekly')
      expect(pref.preference(:digest_sms)).to eq('off')
    end

    it 'redirects to about_me when return_url is not present' do
      patch :update, params: {
        organization_id: company.to_param,
        digest_email: 'off',
        commit: 'Save preferences'
      }
      expect(response).to redirect_to(about_me_organization_company_teammate_path(company, teammate))
      expect(flash[:notice]).to eq('Digest preferences saved.')
    end

    it 'when commit is "Save and Test By Sending Now" saves preferences, enqueues job, and redirects to digest edit with queued flash' do
      expect {
        patch :update, params: {
          organization_id: company.to_param,
          digest_slack: 'weekly',
          digest_email: 'off',
          digest_sms: 'off',
          return_url: organization_get_shit_done_path(company),
          return_text: 'Back to list',
          commit: 'Save and Test By Sending Now'
        }
      }.to have_enqueued_job(Digest::SendDigestJob).with(teammate.id)

      expect(response).to redirect_to(edit_organization_digest_path(company, return_url: organization_get_shit_done_path(company), return_text: 'Back to list'))
      expect(flash[:notice]).to eq('Digests have been queued to send and should be delivered in the next minute or so.')
    end
  end
end
