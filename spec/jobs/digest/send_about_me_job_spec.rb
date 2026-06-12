# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::SendAboutMeJob, type: :job do
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

  it 'opens a group dm and posts main plus About Me section thread' do
    slack_service = instance_double(SlackService)
    allow(SlackService).to receive(:new).and_return(slack_service)
    allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'G123' })
    allow(slack_service).to receive(:post_message).and_return({ success: true })
    allow_any_instance_of(Notification).to receive(:reload) { |n| n.update_column(:message_id, '123.456') if n.message_id.blank?; n }

    expect(Digest::SyncOneOnOneAsanaForAboutMe).not_to receive(:call)

    expect {
      described_class.perform_now(employee.id, '2026-16')
    }.to change { Notification.where(notification_type: 'about_me_digest').count }.by(2)

    expect(slack_service).to have_received(:open_or_create_group_dm).with(user_ids: contain_exactly('UEMP', 'UMGR'))
    expect(UserPreference.for_person(employee_person).preference(:about_me_last_sent_week)).to eq('2026-16')
  end

  it 'sends a direct dm when only one slack identity exists' do
    manager.teammate_identities.where(provider: 'slack').delete_all

    slack_service = instance_double(SlackService)
    allow(SlackService).to receive(:new).and_return(slack_service)
    allow(slack_service).to receive(:open_dm).and_return({ success: true, channel_id: 'D123' })
    allow(slack_service).to receive(:open_or_create_group_dm)
    allow(slack_service).to receive(:post_message).and_return({ success: true })
    allow_any_instance_of(Notification).to receive(:reload) { |n| n.update_column(:message_id, '123.456') if n.message_id.blank?; n }

    described_class.perform_now(employee.id, '2026-17')

    expect(slack_service).to have_received(:open_dm).with(user_id: 'UEMP')
    expect(slack_service).not_to have_received(:open_or_create_group_dm)
  end

  it 'does not send when neither employee nor manager has a slack identity' do
    employee.teammate_identities.where(provider: 'slack').delete_all
    manager.teammate_identities.where(provider: 'slack').delete_all

    expect(SlackService).not_to receive(:new)
    expect {
      described_class.perform_now(employee.id, '2026-19')
    }.not_to change { Notification.where(notification_type: 'about_me_digest').count }
  end
end
