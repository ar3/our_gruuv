# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Digest', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, organization: company, person: person) }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/digest/edit' do
    it 'renders the digest edit page' do
      get edit_organization_digest_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Digest settings')
      expect(response.body).to include('Slack')
      expect(response.body).to include('Save and Test By Sending Now')
    end

    it 'shows back link when return_url and return_text are provided' do
      get edit_organization_digest_path(company),
          params: { return_url: organization_get_shit_done_path(company), return_text: 'Back to list' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Back to list')
    end
  end

  describe 'PATCH /organizations/:organization_id/digest' do
    it 'updates preferences and redirects to return_url when given (Save preferences button)' do
      return_url = organization_get_shit_done_path(company)
      patch organization_digest_path(company),
            params: {
              digest_slack: 'weekly',
              digest_email: 'off',
              digest_sms: 'weekly',
              return_url: return_url,
              return_text: 'Back to GSD',
              commit: 'Save preferences'
            }
      expect(response).to redirect_to(return_url)
      expect(flash[:notice]).to eq('Digest preferences saved.')

      pref = UserPreference.for_person(person).reload
      expect(pref.preference(:digest_email)).to eq('off')
      expect(pref.preference(:digest_sms)).to eq('weekly')
    end

    it 'saves preferences, enqueues digest job, and stays on configuration page when "Save and Test By Sending Now" is clicked' do
      expect {
        patch organization_digest_path(company),
              params: {
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

      pref = UserPreference.for_person(person).reload
      expect(pref.preference(:digest_slack)).to eq('weekly')
    end

    it 'Save and Test By Sending Now redirects back to digest edit with no return_url when opened directly' do
      patch organization_digest_path(company),
            params: {
              digest_slack: 'weekly',
              digest_email: 'off',
              digest_sms: 'off',
              commit: 'Save and Test By Sending Now'
            }

      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(flash[:notice]).to eq('Digests have been queued to send and should be delivered in the next minute or so.')
    end
  end

  describe 'Profile page includes digest section when viewing self' do
    it 'shows Digest section with Configure digest link on own profile' do
      get organization_company_teammate_path(company, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Digest')
      expect(response.body).to include('Configure digest')
    end
  end
end
