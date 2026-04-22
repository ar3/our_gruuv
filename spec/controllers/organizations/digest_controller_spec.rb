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
    it 'updates digest preferences and stays on digest page (Save preferences button)' do
      return_url = organization_get_shit_done_path(company)
      patch :update, params: {
        organization_id: company.to_param,
        digest_slack: 'on',
        digest_email: 'on',
        digest_sms: 'off',
        return_url: return_url,
        return_text: 'Back to list',
        commit: 'Save preferences'
      }
      expect(response).to redirect_to(edit_organization_digest_path(company, return_url: return_url, return_text: 'Back to list'))
      expect(flash[:notice]).to eq('Digest preferences saved.')

      pref = UserPreference.for_person(person).reload
      expect(pref.preference(:digest_slack)).to eq('on')
      expect(pref.preference(:digest_email)).to eq('on')
      expect(pref.preference(:digest_sms)).to eq('off')
    end

    it 'redirects to digest page when return_url is not present' do
      patch :update, params: {
        organization_id: company.to_param,
        digest_sms: 'on',
        digest_email: 'off',
        commit: 'Save preferences'
      }
      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(flash[:notice]).to eq('Digest preferences saved.')
    end

    it 'shows danger alert when both Slack and SMS are off' do
      patch :update, params: {
        organization_id: company.to_param,
        digest_slack: 'off',
        digest_sms: 'off',
        digest_email: 'off',
        commit: 'Save preferences'
      }

      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(flash[:alert]).to eq('No notifications will be sent since no mediums are configured to send notifications to.')
    end

    it 'updates about me weekly day for a direct report when about_me_days is submitted' do
      report_person = create(:person)
      report = create(:company_teammate, organization: company, person: report_person)
      create(:employment_tenure, teammate: report, company: company, manager_teammate: teammate, started_at: 1.year.ago, ended_at: nil)
      report.update!(first_employed_at: 1.year.ago)

      patch :update, params: {
        organization_id: company.to_param,
        digest_slack: 'on',
        digest_email: 'off',
        digest_sms: 'off',
        about_me_days: { report.id.to_s => '4' },
        commit: 'Save preferences'
      }

      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(UserPreference.for_person(report_person).preference(:about_me_weekly_day)).to eq('4')
    end
  end

  describe 'POST #send_gsd_test' do
    it 'queues GSD send job and redirects to digest edit' do
      allow_any_instance_of(GetShitDoneQueryService).to receive(:all_pending_items).and_return({ total_pending: 1 })
      expect {
        post :send_gsd_test, params: { organization_id: company.to_param }
      }.to have_enqueued_job(Digest::SendDigestJob).with(teammate.id)
      expect(response).to redirect_to(edit_organization_digest_path(company))
    end

    it 'does not queue test when user has no GSD items' do
      allow_any_instance_of(GetShitDoneQueryService).to receive(:all_pending_items).and_return({ total_pending: 0 })
      expect {
        post :send_gsd_test, params: { organization_id: company.to_param }
      }.not_to have_enqueued_job(Digest::SendDigestJob)
      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(flash[:alert]).to match(/No test sent/)
    end
  end

  describe 'POST #send_about_me_test' do
    it 'queues About Me send job for teammate and redirects to digest edit' do
      expect {
        post :send_about_me_test, params: { organization_id: company.to_param, teammate_id: teammate.id }
      }.to have_enqueued_job(Digest::SendAboutMeJob).with(teammate.id)
      expect(response).to redirect_to(edit_organization_digest_path(company))
    end
  end
end
