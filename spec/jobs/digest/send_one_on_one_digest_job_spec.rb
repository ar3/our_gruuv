# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::SendOneOnOneDigestJob, type: :job do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let(:employee) { create(:company_teammate, person: employee_person, organization: organization) }
  let(:manager) { create(:company_teammate, person: manager_person, organization: organization) }

  before do
    create(:employment_tenure, teammate: employee, company: organization, manager_teammate: manager, started_at: 1.year.ago, ended_at: nil)
    employee.update!(first_employed_at: 1.year.ago)
    manager.update!(first_employed_at: 1.year.ago)
    create(:teammate_identity, :slack, teammate: employee, uid: 'UEMP')
    create(:teammate_identity, :slack, teammate: manager, uid: 'UMGR')
    allow_any_instance_of(Organization).to receive(:calculated_slack_config).and_return(double('SlackConfig', configured?: true))
  end

  it 'opens a group dm and posts main plus thread messages' do
    slack_service = instance_double(SlackService)
    allow(SlackService).to receive(:new).and_return(slack_service)
    allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'G123' })
    allow(slack_service).to receive(:post_message).and_return({ success: true })
    allow_any_instance_of(Notification).to receive(:reload) { |n| n.update_column(:message_id, '123.456') if n.message_id.blank?; n }
    allow(Digest::SyncOneOnOneAsanaForAboutMe).to receive(:call).and_return(synced: false, skipped: :no_link)

    expect {
      described_class.perform_now(employee.id, '2026-16')
    }.to change { Notification.where(notification_type: 'one_on_one_digest').count }.by(2)

    expect(Digest::SyncOneOnOneAsanaForAboutMe).to have_received(:call).with(
      employee_teammate: employee,
      manager_teammate: manager
    )

    expect(slack_service).to have_received(:open_or_create_group_dm).with(user_ids: contain_exactly('UEMP', 'UMGR'))
    expect(UserPreference.for_person(employee_person).preference(:one_on_one_last_sent_week)).to eq('2026-16')
  end

  it 'does not send when neither employee nor manager has a slack identity' do
    employee.teammate_identities.where(provider: 'slack').delete_all
    manager.teammate_identities.where(provider: 'slack').delete_all

    expect(SlackService).not_to receive(:new)
    expect {
      described_class.perform_now(employee.id, '2026-19')
    }.not_to change { Notification.where(notification_type: 'one_on_one_digest').count }
  end
end
