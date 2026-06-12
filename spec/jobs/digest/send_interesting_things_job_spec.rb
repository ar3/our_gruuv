# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::SendInterestingThingsJob, type: :job do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) do
    t = create(:company_teammate, person: person, organization: organization)
    create(:employment_tenure, teammate: t, company: organization, started_at: 1.year.ago, ended_at: nil)
    t.update!(first_employed_at: 1.year.ago)
    t
  end

  describe '#perform' do
    it 'does nothing when there is nothing interesting to show' do
      allow_any_instance_of(Digest::InterestingThingsMessageBuilderService).to receive(:total_count).and_return(0)
      expect(SlackService).not_to receive(:new)

      expect {
        described_class.perform_now(teammate.id)
      }.not_to change { Notification.where(notification_type: 'interesting_things_digest').count }
    end

    context 'when there is something to show' do
      before do
        create(:teammate_identity, :slack, teammate: teammate, uid: 'U123')
        allow_any_instance_of(Organization).to receive(:calculated_slack_config).and_return(double('SlackConfig', configured?: true))
        allow_any_instance_of(Digest::InterestingThingsMessageBuilderService).to receive(:total_count).and_return(2)
        allow_any_instance_of(Digest::InterestingThingsMessageBuilderService).to receive(:main_message)
          .and_return({ blocks: [{ type: 'section', text: { type: 'mrkdwn', text: 'hi' } }], text: 'hi' })
        allow_any_instance_of(Digest::InterestingThingsMessageBuilderService).to receive(:thread_payloads)
          .and_return([{ blocks: [{ type: 'section', text: { type: 'mrkdwn', text: 'detail' } }], text: 'detail' }])
      end

      it 'opens a DM as ourgruuvbot and posts main plus thread notifications' do
        slack_service = instance_double(SlackService)
        allow(SlackService).to receive(:new).and_return(slack_service)
        allow(slack_service).to receive(:open_dm).with(user_id: 'U123').and_return({ success: true, channel_id: 'D123' })
        allow(slack_service).to receive(:post_message).and_return({ success: true })
        allow_any_instance_of(Notification).to receive(:reload) { |n| n.update_column(:message_id, '123.456') if n.message_id.blank?; n }
        allow_any_instance_of(Notification).to receive(:message_id).and_return('123.456')

        expect {
          described_class.perform_now(teammate.id)
        }.to change { Notification.where(notification_type: 'interesting_things_digest').count }.by(2)

        main_notification = Notification.where(notification_type: 'interesting_things_digest').order(:id).first
        expect(main_notification.metadata['channel']).to eq('D123')
        expect(main_notification.metadata['username']).to eq('ourgruuvbot')
      end

      it 'skips Slack when the teammate has no Slack identity' do
        teammate.teammate_identities.where(provider: 'slack').delete_all
        expect(SlackService).not_to receive(:new)
        described_class.perform_now(teammate.id)
      end
    end
  end
end
