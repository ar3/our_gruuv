require 'rails_helper'

RSpec.describe Observations::PostNotificationJob, type: :job do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    create(:observation_rating, observation: obs, rateable: create(:ability, organization: company), rating: :strongly_agree)
    obs
  end

  let(:slack_service) { double('SlackService') }

  before do
    observer_teammate # Ensure observer teammate is created
    # Create Slack identities for the people
    create(:person_identity, person: observer, provider: 'slack', uid: 'U123456')
    create(:person_identity, person: observee_person, provider: 'slack', uid: 'U789012')
    allow(SlackService).to receive(:new).and_return(slack_service)
    allow(slack_service).to receive(:post_message).and_return({ success: true, message_id: '1234567890.123456' })
  end

  describe '#perform' do
    context 'when sending DMs' do
      let(:notification_options) { { send_dms: true } }

      it 'creates notifications for each observee' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notification_options)
        }.to change(Notification, :count).by(1)
      end

      it 'sends DM to observee with Slack user ID' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notification_options)
        
        notification = Notification.last
        expect(notification.notification_type).to eq('observation_dm')
        expect(notification.status).to eq('sent_successfully')
        expect(notification.message_id).to eq('1234567890.123456')
        expect(notification.metadata['slack_user_id']).to eq('U789012')
      end

      it 'skips observees without Slack user ID' do
        observee_person.person_identities.destroy_all # Remove Slack identity
        
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notification_options)
        }.not_to change(Notification, :count)
      end

      it 'handles Slack API errors gracefully' do
        allow(slack_service).to receive(:post_message).and_raise(StandardError.new('Slack API error'))
        
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notification_options)
        }.to change(Notification, :count).by(1)
        
        notification = Notification.last
        expect(notification.status).to eq('send_failed')
        expect(notification.metadata['error']).to eq('Slack API error')
      end
    end

    context 'when sending to channels' do
      let(:notification_options) { 
        { 
          send_dms: false,
          send_to_channels: true, 
          channel_ids: ['C123456', 'C789012'] 
        } 
      }

      before do
        observation.update!(privacy_level: :public_observation)
      end

      it 'creates notifications for each channel' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notification_options)
        }.to change(Notification, :count).by(2)
      end

      it 'sends to each specified channel' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notification_options)
        
        notifications = Notification.last(2)
        expect(notifications.map(&:notification_type)).to all(eq('observation_channel'))
        expect(notifications.map(&:status)).to all(eq('sent_successfully'))
        expect(notifications.map { |n| n.metadata['channel_id'] }).to contain_exactly('C123456', 'C789012')
      end

      it 'handles Slack API errors for channels' do
        allow(slack_service).to receive(:post_message).and_raise(StandardError.new('Channel error'))
        
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notification_options)
        }.to change(Notification, :count).by(2)
        
        notifications = Notification.last(2)
        expect(notifications.map(&:status)).to all(eq('send_failed'))
      end
    end

    context 'when sending both DMs and channels' do
      let(:notification_options) { 
        { 
          send_dms: true,
          send_to_channels: true, 
          channel_ids: ['C123456'] 
        } 
      }

      before do
        observation.update!(privacy_level: :public_observation)
      end

      it 'creates notifications for both DMs and channels' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notification_options)
        }.to change(Notification, :count).by(2) # 1 DM + 1 channel
      end
    end

    context 'when observation cannot post to Slack' do
      before do
        observation.update!(privacy_level: :observer_only)
        # Remove Slack identity so can_post_to_slack? returns false
        observee_person.person_identities.destroy_all
      end

      it 'does not create any notifications' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, { send_dms: true })
        }.not_to change(Notification, :count)
      end
    end

    context 'message content' do
      let(:notification_options) { { send_dms: true } }

      it 'includes observation details in DM message' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notification_options)
        
        notification = Notification.last
        expect(notification.rich_message).to include('New Observation from')
        expect(notification.rich_message).to include(observer.preferred_name || observer.first_name)
        expect(notification.rich_message).to include(observation.story.truncate(200))
        expect(notification.rich_message).to include('View Kudos')
      end

      it 'includes observation details in channel message' do
        observation.update!(privacy_level: :public_observation)
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, { send_to_channels: true, channel_ids: ['C123456'] })
        
        notification = Notification.last
        expect(notification.rich_message).to include('recognized')
        expect(notification.rich_message).to include(observee_person.preferred_name || observee_person.first_name)
        expect(notification.rich_message).to include(observation.story)
      end

      it 'includes ratings summary' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notification_options)
        
        notification = Notification.last
        expect(notification.rich_message).to include('Ratings:')
        expect(notification.rich_message).to include('⭐') # strongly_agree emoji
      end
    end
  end
end
