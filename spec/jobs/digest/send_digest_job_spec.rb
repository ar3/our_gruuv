# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::SendDigestJob, type: :job do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  describe '#perform' do
    it 'does not send when teammate has no Slack identity' do
      expect(SlackService).not_to receive(:new)
      described_class.perform_now(teammate.id)
    end

    context 'when teammate has Slack identity and org has Slack configured' do
      before do
        create(:teammate_identity, :slack, teammate: teammate, uid: 'U123')
        allow_any_instance_of(Organization).to receive(:calculated_slack_config).and_return(double('SlackConfig', configured?: true))
        slack_service = instance_double(SlackService, post_message: { success: true }, open_dm: { success: true, channel_id: 'D0G9XK8HV' })
        allow(SlackService).to receive(:new).and_return(slack_service)
        allow_any_instance_of(Notification).to receive(:reload) { |n| n.update_column(:message_id, '123.456') if n.message_id.blank?; n }
        allow_any_instance_of(Notification).to receive(:message_id).and_return('123.456')
      end

      it 'opens DM with user, creates main + two thread notifications, and posts as ourgruuvbot' do
        UserPreference.for_person(person).update_preference('digest_slack', 'weekly')
        slack_service = instance_double(SlackService)
        allow(SlackService).to receive(:new).and_return(slack_service)
        allow(slack_service).to receive(:open_dm).with(user_id: 'U123').and_return({ success: true, channel_id: 'D0G9XK8HV' })
        allow(slack_service).to receive(:post_message).and_return({ success: true })
        notif_double = double('Notification', message_id: '123.456')
        allow_any_instance_of(Notification).to receive(:reload).and_return(notif_double)
        allow(notif_double).to receive(:message_id).and_return('123.456')

        expect {
          described_class.perform_now(teammate.id)
        }.to change { Notification.where(notification_type: 'gsd_digest').count }.by(3)

        expect(slack_service).to have_received(:open_dm).with(user_id: 'U123')
        expect(slack_service).to have_received(:post_message).exactly(3).times
        main_notification = Notification.where(notification_type: 'gsd_digest').order(:id).first
        expect(main_notification.metadata['channel']).to eq('D0G9XK8HV')
        expect(main_notification.metadata['username']).to eq('ourgruuvbot')
      end
    end

    context 'when digest_sms is on and person has phone' do
      before do
        person.update!(unique_textable_phone_number: '+15551234567')
        UserPreference.for_person(person).update_preference('digest_sms', 'weekly')
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('NOTIFICATION_API_CLIENT_ID').and_return('client_id')
        allow(ENV).to receive(:[]).with('NOTIFICATION_API_CLIENT_SECRET').and_return('secret')
      end

      it 'calls NotificationApiService#send_notification with SMS message' do
        service = instance_double(NotificationApiService, send_notification: { success: true })
        allow(NotificationApiService).to receive(:new).and_return(service)

        described_class.perform_now(teammate.id)

        expect(service).to have_received(:send_notification).with(
          hash_including(
            type: 'gsd_digest_sms',
            to: { id: person.email, number: '+15551234567' },
            sms: { message: a_kind_of(String) }
          )
        )
        expect(service).to have_received(:send_notification) do |args|
          expect(args[:sms][:message]).to be_present
        end
      end
    end

    it 'does not call NotificationApiService when person has no phone' do
      person.update!(unique_textable_phone_number: nil)
      UserPreference.for_person(person).update_preference('digest_sms', 'weekly')
      expect(NotificationApiService).not_to receive(:new)
      described_class.perform_now(teammate.id)
    end
  end
end
