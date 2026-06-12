# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications tab', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, timezone: 'America/Los_Angeles') }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:company_teammate_id/notifications' do
    it 'renders for the teammate themself' do
      get organization_company_teammate_notifications_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Send Weekly Digests')
      expect(response.body).to include('How do you want these notifications?')
      # Auto-save forms exist and the day button group inputs are bound to the weekly form
      expect(response.body).to include('id="weekly-digest-form"')
      expect(response.body).to include("about_me_days[#{teammate.id}]")
      expect(response.body).to include('gsd_digest_enabled')
      expect(response.body).to include('interesting_things_digest_enabled')
    end

    it 'shows the weekly style multi-select once a day is selected, defaulting 1:1 on' do
      UserPreference.for_person(person).update_preference('about_me_weekly_day', '2')

      get organization_company_teammate_notifications_path(organization, teammate)
      expect(response.body).to include('Which style to send')
      one_on_one_checkbox = response.body[/<input[^>]*id="weekly_one_on_one_digest"[^>]*>/]
      expect(one_on_one_checkbox).to include('checked')
    end

    it 'renders for the direct manager' do
      manager_person = create(:person)
      manager = create(:company_teammate, person: manager_person, organization: organization)
      create(:employment_tenure, teammate: manager, company: organization, started_at: 1.year.ago, ended_at: nil)
      manager.update!(first_employed_at: 1.year.ago)
      teammate.active_employment_tenure.update!(manager_teammate: manager)
      sign_in_as_teammate_for_request(manager_person, organization)

      get organization_company_teammate_notifications_path(organization, teammate)
      expect(response).to have_http_status(:success)
    end

    it 'denies an unrelated teammate' do
      other_person = create(:person)
      other = create(:company_teammate, person: other_person, organization: organization)
      create(:employment_tenure, teammate: other, company: organization, started_at: 1.year.ago, ended_at: nil)
      other.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(other_person, organization)

      get organization_company_teammate_notifications_path(organization, teammate)
      expect(response).to have_http_status(:redirect)
    end

    it 'lists direct reports with their notification summary' do
      report_person = create(:person, first_name: 'Ripley', last_name: 'Reportstein')
      report = create(:company_teammate, person: report_person, organization: organization)
      create(:employment_tenure, teammate: report, company: organization, manager_teammate: teammate, started_at: 1.year.ago, ended_at: nil)
      report.update!(first_employed_at: 1.year.ago)

      get organization_company_teammate_notifications_path(organization, teammate)
      expect(response.body).to include('Ripley')
      expect(response.body).to include(organization_company_teammate_notifications_path(organization, report))
    end
  end

  describe 'PATCH /organizations/:organization_id/company_teammates/:company_teammate_id/notifications' do
    it 'saves the GSD toggle' do
      patch organization_company_teammate_notifications_path(organization, teammate), params: { gsd_digest_enabled: 'on' }
      expect(response).to redirect_to(organization_company_teammate_notifications_path(organization, teammate))
      expect(UserPreference.for_person(person).gsd_digest_enabled?).to be(true)
    end

    it 'saves the Interesting Things toggle' do
      patch organization_company_teammate_notifications_path(organization, teammate), params: { interesting_things_digest_enabled: 'on' }
      expect(UserPreference.for_person(person).interesting_things_digest_enabled?).to be(true)
    end

    it 'saves the weekly day and defaults the 1:1 guide on' do
      patch organization_company_teammate_notifications_path(organization, teammate),
            params: { about_me_days: { teammate.id.to_s => '2' } }
      prefs = UserPreference.for_person(person)
      expect(prefs.preference(:about_me_weekly_day)).to eq('2')
      expect(prefs.preference(:one_on_one_digest_enabled)).to eq('on')
    end

    it 'saves the SMS channel' do
      patch organization_company_teammate_notifications_path(organization, teammate), params: { digest_sms: 'on' }
      expect(UserPreference.for_person(person).effective_digest_sms(person)).to eq('on')
    end

    it 'allows a manager to update a direct report' do
      manager_person = create(:person)
      manager = create(:company_teammate, person: manager_person, organization: organization)
      create(:employment_tenure, teammate: manager, company: organization, started_at: 1.year.ago, ended_at: nil)
      manager.update!(first_employed_at: 1.year.ago)
      teammate.active_employment_tenure.update!(manager_teammate: manager)
      sign_in_as_teammate_for_request(manager_person, organization)

      patch organization_company_teammate_notifications_path(organization, teammate), params: { gsd_digest_enabled: 'on' }
      expect(UserPreference.for_person(person).gsd_digest_enabled?).to be(true)
    end

    it 'denies an unrelated teammate' do
      other_person = create(:person)
      other = create(:company_teammate, person: other_person, organization: organization)
      create(:employment_tenure, teammate: other, company: organization, started_at: 1.year.ago, ended_at: nil)
      other.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(other_person, organization)

      patch organization_company_teammate_notifications_path(organization, teammate), params: { gsd_digest_enabled: 'on' }
      expect(UserPreference.for_person(person).gsd_digest_enabled?).to be(false)
    end
  end

  describe 'test sends' do
    it 'queues an Interesting Things test when there is something to show' do
      allow_any_instance_of(SomethingInterestingQueryService).to receive(:total_count).and_return(3)

      expect {
        post send_interesting_things_test_organization_company_teammate_notifications_path(organization, teammate)
      }.to have_enqueued_job(Digest::SendInterestingThingsJob).with(teammate.id)
    end

    it 'does not queue an Interesting Things test when there is nothing to show' do
      allow_any_instance_of(SomethingInterestingQueryService).to receive(:total_count).and_return(0)

      expect {
        post send_interesting_things_test_organization_company_teammate_notifications_path(organization, teammate)
      }.not_to have_enqueued_job(Digest::SendInterestingThingsJob)
    end

    it 'does not queue a GSD test when the list is empty' do
      allow_any_instance_of(GetShitDoneQueryService).to receive(:all_pending_items).and_return({ total_pending: 0 })

      expect {
        post send_gsd_test_organization_company_teammate_notifications_path(organization, teammate)
      }.not_to have_enqueued_job(Digest::SendDigestJob)
    end

    it 'queues weekly digests based on toggles' do
      prefs = UserPreference.for_person(person)
      prefs.update_preference('one_on_one_digest_enabled', 'on')
      prefs.update_preference('about_me_digest_enabled', 'off')

      expect {
        post send_weekly_digests_now_organization_company_teammate_notifications_path(organization, teammate)
      }.to have_enqueued_job(Digest::SendOneOnOneDigestJob).with(teammate.id)
    end
  end
end
