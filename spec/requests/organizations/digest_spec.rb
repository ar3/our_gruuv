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
      expect(response.body).to include('Send test (Get Shit Done)')
    end

    it 'shows back link when return_url and return_text are provided' do
      get edit_organization_digest_path(company),
          params: { return_url: organization_get_shit_done_path(company), return_text: 'Back to list' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Back to list')
    end
  end

  describe 'POST /organizations/:organization_id/digest/sync_all_mediums' do
    it 'sets slack, email, and SMS digest to the same value and redirects to Start Here' do
      UserPreference.for_person(person).update_preference('digest_slack', 'off')
      UserPreference.for_person(person).update_preference('digest_email', 'on')
      UserPreference.for_person(person).update_preference('digest_sms', 'on')

      post sync_all_mediums_organization_digest_path(company), params: { value: 'on' }

      expect(response).to redirect_to(organization_start_here_path(company))
      pref = UserPreference.for_person(person).reload
      expect(pref.preference(:digest_slack)).to eq('on')
      expect(pref.preference(:digest_email)).to eq('on')
      expect(pref.preference(:digest_sms)).to eq('on')
    end

    it 'rejects invalid value' do
      post sync_all_mediums_organization_digest_path(company), params: { value: 'weekly' }
      expect(response).to redirect_to(organization_start_here_path(company))
      expect(flash[:alert]).to match(/Invalid digest schedule/)
    end
  end

  describe 'PATCH /organizations/:organization_id/digest' do
    it 'updates preferences and stays on digest page when saving' do
      return_url = organization_get_shit_done_path(company)
      patch organization_digest_path(company),
            params: {
              digest_slack: 'weekly',
              digest_sms: 'on',
              digest_email: 'off',
              return_url: return_url,
              return_text: 'Back to GSD',
              commit: 'Save preferences'
            }
      expect(response).to redirect_to(edit_organization_digest_path(company, return_url: return_url, return_text: 'Back to GSD'))
      expect(flash[:notice]).to eq('Digest preferences saved.')

      pref = UserPreference.for_person(person).reload
      expect(pref.preference(:digest_email)).to eq('off')
      expect(pref.preference(:digest_sms)).to eq('on')
    end

    it 'shows danger alert when both Slack and SMS are off' do
      patch organization_digest_path(company),
            params: {
              digest_slack: 'off',
              digest_email: 'off',
              digest_sms: 'off',
              commit: 'Save preferences'
            }
      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(flash[:alert]).to eq('No notifications will be sent since no mediums are configured to send notifications to.')
    end

    it 'saves about me weekly day for a direct report from digest settings payload' do
      report_person = create(:person)
      report = create(:company_teammate, organization: company, person: report_person)
      create(:employment_tenure, teammate: report, company: company, manager_teammate: teammate, started_at: 1.year.ago, ended_at: nil)
      report.update!(first_employed_at: 1.year.ago)

      patch organization_digest_path(company),
            params: {
              digest_slack: 'on',
              digest_email: 'off',
              digest_sms: 'off',
              about_me_days: { report.id.to_s => '2' },
              commit: 'Save preferences'
            }

      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(UserPreference.for_person(report_person).preference(:about_me_weekly_day)).to eq('2')
    end
  end

  describe 'POST /organizations/:organization_id/digest/send_gsd_test' do
    it 'queues GSD send test and redirects to digest page' do
      allow_any_instance_of(GetShitDoneQueryService).to receive(:all_pending_items).and_return({ total_pending: 1 })
      expect {
        post send_gsd_test_organization_digest_path(company)
      }.to have_enqueued_job(Digest::SendDigestJob).with(teammate.id)
      expect(response).to redirect_to(edit_organization_digest_path(company))
    end

    it 'does not queue GSD test when no items exist' do
      allow_any_instance_of(GetShitDoneQueryService).to receive(:all_pending_items).and_return({ total_pending: 0 })
      expect {
        post send_gsd_test_organization_digest_path(company)
      }.not_to have_enqueued_job(Digest::SendDigestJob)
      expect(response).to redirect_to(edit_organization_digest_path(company))
      expect(flash[:alert]).to match(/No test sent/)
    end
  end

  describe 'POST /organizations/:organization_id/digest/send_about_me_test' do
    it 'queues About Me send test and redirects to digest page' do
      expect {
        post send_about_me_test_organization_digest_path(company), params: { teammate_id: teammate.id }
      }.to have_enqueued_job(Digest::SendAboutMeJob).with(teammate.id)
      expect(response).to redirect_to(edit_organization_digest_path(company))
    end
  end

  describe 'Profile page includes digest section when viewing self' do
    it 'shows Digest section with Configure digest link on own profile' do
      get organization_company_teammate_path(company, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Digest')
      expect(response.body).to include('Configure digest')
    end

    it 'saves 1:1 day from profile flow via digest update endpoint' do
      patch organization_digest_path(company),
            params: {
              digest_slack: 'on',
              digest_email: 'off',
              digest_sms: 'off',
              about_me_days: { teammate.id.to_s => '5' },
              return_url: organization_company_teammate_path(company, teammate),
              return_text: 'Back to Profile',
              commit: 'Save 1:1 day'
            }

      expect(response).to redirect_to(organization_company_teammate_path(company, teammate))
      expect(UserPreference.for_person(person).preference(:about_me_weekly_day)).to eq('5')
    end
  end
end
