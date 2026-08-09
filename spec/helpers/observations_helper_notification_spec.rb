require 'rails_helper'

RSpec.describe ObservationsHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee) { create(:person, first_name: 'Observed', last_name: 'Person') }
  let(:observee_teammate) { create(:teammate, person: observee, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish!
    obs
  end

  describe '#observation_root_notification_attempts' do
    let!(:main) do
      Notification.create!(
        notifiable: observation,
        notification_type: 'observation_channel',
        status: 'send_failed',
        metadata: { 'is_main_message' => true, 'organization_id' => company.id.to_s, 'channel' => 'C1' }
      )
    end
    let!(:thread) do
      Notification.create!(
        notifiable: observation,
        notification_type: 'observation_channel',
        status: 'sent_successfully',
        main_thread: main,
        metadata: { 'is_thread_reply' => true, 'organization_id' => company.id.to_s, 'channel' => 'C1' }
      )
    end
    let!(:edit) do
      Notification.create!(
        notifiable: observation,
        notification_type: 'observation_channel',
        status: 'sent_successfully',
        original_message: main,
        metadata: { 'is_main_message' => true, 'organization_id' => company.id.to_s, 'channel' => 'C1' }
      )
    end

    it 'returns root attempts and excludes thread replies and edits' do
      result = helper.observation_root_notification_attempts(observation.notifications, type: 'observation_channel')
      expect(result).to eq([main])
    end
  end

  describe '#observation_notification_destination_label' do
    it 'builds channel destination from org and channel display names' do
      channel = create(:third_party_object, :slack_channel, organization: company, third_party_id: 'Ckudos', display_name: '#kudos')
      n = Notification.create!(
        notifiable: observation,
        notification_type: 'observation_channel',
        status: 'send_failed',
        metadata: {
          'organization_id' => company.id.to_s,
          'channel' => channel.third_party_id
        }
      )
      expect(helper.observation_notification_destination_label(n)).to eq("#{company.display_name} - #kudos")
    end

    it 'builds private destination from teammate names' do
      n = Notification.create!(
        notifiable: observation,
        notification_type: 'observation_dm',
        status: 'send_failed',
        metadata: {
          'teammate_ids' => [observee_teammate.id, observer_teammate.id],
          'channel' => 'G123'
        }
      )
      label = helper.observation_notification_destination_label(n)
      expect(label).to include(observee.casual_name)
      expect(label).to include(observer.casual_name)
    end
  end

  describe '#observation_notification_status_phrase' do
    it 'maps statuses to attempt phrases' do
      expect(helper.observation_notification_status_phrase('sent_successfully')).to eq('Sent to')
      expect(helper.observation_notification_status_phrase('send_failed')).to eq('Tried to send to')
      expect(helper.observation_notification_status_phrase('preparing_to_send')).to eq('Sending to')
    end
  end
end
