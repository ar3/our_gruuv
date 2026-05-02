# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Check-in acknowledgement nudges', type: :request do
  let(:company) { create(:organization, :company, :with_slack_config) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) do
    create(:teammate, :employment_manager, :assigned_employee, person: manager_person, organization: company)
  end
  let(:employee_person) { create(:person) }
  let(:employee_teammate) do
    create(:teammate, :assigned_employee, person: employee_person, organization: company)
  end

  before do
    manager_teammate
    employee_teammate
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: 'UMGRTEST')
    create(:teammate_identity, :slack, teammate: employee_teammate, uid: 'UEMPTEST')
    sign_in_as_teammate_for_request(manager_person, company)
    allow_any_instance_of(SlackService).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'GTESTCHAN' })
    allow_any_instance_of(SlackService).to receive(:post_message) do |_slack_service, notification_id|
      Notification.find(notification_id).update!(status: 'sent_successfully', message_id: '9999.1111')
      { success: true, message_id: '9999.1111' }
    end
  end

  describe 'GET /organizations/:organization_id/check_ins_acknowledgement_nudges' do
    it 'returns success and shows table headers' do
      get organization_check_ins_acknowledgement_nudges_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Check-in acknowledgement nudges')
      expect(response.body).to include('Who to show')
      expect(response.body).to include('Unacknowledged')
    end

    it 'shows Yes when teammate has pending snapshot' do
      create(:maap_snapshot, :executed, employee_company_teammate: employee_teammate, company: company,
                                         creator_company_teammate: manager_teammate)

      get organization_check_ins_acknowledgement_nudges_path(company, manager_id: 'everyone')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Yes')
    end
  end

  describe 'POST /organizations/:organization_id/check_ins_acknowledgement_nudges/nudge' do
    before do
      create(:maap_snapshot, :executed, employee_company_teammate: employee_teammate, company: company,
                                         creator_company_teammate: manager_teammate)
    end

    it 'sends a nudge and redirects with notice' do
      expect do
        post organization_check_ins_acknowledgement_nudges_nudge_path(company),
             params: { company_teammate_id: employee_teammate.id, manager_id: 'everyone' }
      end.to change(Notification.where(notification_type: 'check_in_acknowledgement_nudge'), :count).by(1)

      expect(response).to redirect_to(organization_check_ins_acknowledgement_nudges_path(company, manager_id: 'everyone'))
      follow_redirect!
      expect(response.body).to include('Nudge sent.')
    end
  end
end
