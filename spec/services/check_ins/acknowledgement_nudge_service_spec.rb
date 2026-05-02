# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::AcknowledgementNudgeService do
  let(:company) { create(:organization, :company, :with_slack_config) }
  let(:employee_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:nudger_teammate) { create(:teammate, :assigned_employee, organization: company) }

  before do
    create(:teammate_identity, :slack, teammate: employee_teammate, uid: 'U111EMPLOYEE')
    create(:teammate_identity, :slack, teammate: nudger_teammate, uid: 'U222NUDGER')
  end

  describe '.call' do
    it 'returns error when there is no pending acknowledgement' do
      result = described_class.call(
        organization: company,
        employee_teammate: employee_teammate,
        nudger_company_teammate: nudger_teammate
      )
      expect(result.ok?).to be false
      expect(result.error).to include('No pending acknowledgements')
    end

    it 'returns error when Slack is missing for nudger or employee' do
      employee_teammate.teammate_identities.destroy_all
      create(:maap_snapshot, :executed, employee_company_teammate: employee_teammate, company: company,
                                         creator_company_teammate: nudger_teammate)

      result = described_class.call(
        organization: company,
        employee_teammate: employee_teammate,
        nudger_company_teammate: nudger_teammate
      )
      expect(result.ok?).to be false
      expect(result.error).to include('Slack')
    end

    it 'creates a notification and posts to Slack when pending snapshot exists' do
      snapshot = create(:maap_snapshot, :executed, employee_company_teammate: employee_teammate, company: company,
                                                     creator_company_teammate: nudger_teammate)

      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm)
        .with(user_ids: %w[U111EMPLOYEE U222NUDGER])
        .and_return({ success: true, channel_id: 'G01234567' })
      allow(slack_service).to receive(:post_message) do |notification_id|
        Notification.find(notification_id).update!(status: 'sent_successfully', message_id: '1234.5678')
        { success: true, message_id: '1234.5678' }
      end

      result = described_class.call(
        organization: company,
        employee_teammate: employee_teammate,
        nudger_company_teammate: nudger_teammate
      )

      expect(result.ok?).to be true
      n = result.value[:notification]
      expect(n.notification_type).to eq('check_in_acknowledgement_nudge')
      expect(n.notifiable).to eq(snapshot)
      expect(n.metadata['channel']).to eq('G01234567')
      expect(n.metadata['nudger_company_teammate_id']).to eq(nudger_teammate.id)
      expect(n.message_id).to eq('1234.5678')
    end
  end
end
