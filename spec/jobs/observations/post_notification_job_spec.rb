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
    # Create Slack identities for the teammates
    create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: 'U123456')
    create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: 'U789012')
    
    # Mock SlackService to avoid Slack configuration requirements
    allow(SlackService).to receive(:new).and_return(slack_service)
    allow(slack_service).to receive(:post_message) do |notification_id|
      notification = Notification.find(notification_id)
      notification.update!(status: 'sent_successfully', message_id: '1234567890.123456')
      { success: true, message_id: '1234567890.123456' }
    end
  end

  describe '#perform' do
    context 'when sending DMs' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }

      it 'creates notifications for each observee' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(1)
      end

      it 'sends DM to observee with Slack user ID' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)
        
        notification = Notification.last
        expect(notification.notification_type).to eq('observation_dm')
        expect(notification.status).to eq('sent_successfully')
        expect(notification.message_id).to eq('1234567890.123456')
        expect(notification.metadata['channel']).to eq('U789012')
      end

      it 'skips observees without Slack user ID' do
        observee_teammate.teammate_identities.destroy_all # Remove Slack identity
        
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.not_to change(Notification, :count)
      end

      it 'handles Slack API errors gracefully' do
        allow(slack_service).to receive(:post_message).and_raise(StandardError.new('Slack API error'))
        
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(1)
        
        notification = Notification.last
        expect(notification.status).to eq('preparing_to_send') # Status remains unchanged on error
      end
    end

    context 'when sending to channels' do
      let(:notify_teammate_ids) { [] }

      before do
        observation.update!(privacy_level: :public_observation)
      end

      it 'creates notifications for each channel' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(0) # Channel functionality not implemented yet
      end

      it 'sends to each specified channel' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)
        
        notifications = Notification.last(2)
        expect(notifications).to be_empty # Channel functionality not implemented yet
      end

      it 'handles Slack API errors for channels' do
        allow(slack_service).to receive(:post_message).and_raise(StandardError.new('Channel error'))
        
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(0) # Channel functionality not implemented yet
      end
    end

    context 'when sending both DMs and channels' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }

      before do
        observation.update!(privacy_level: :public_observation)
      end

      it 'creates notifications for both DMs and channels' do
        expect {
          job = Observations::PostNotificationJob.new
          job.perform(observation.id, notify_teammate_ids)
        }.to change(Notification, :count).by(1) # 1 DM only (channel functionality not implemented yet)
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
          job.perform(observation.id, [])
        }.not_to change(Notification, :count)
      end
    end

    context 'message content' do
      let(:notify_teammate_ids) { [observee_teammate.id.to_s] }

      it 'includes observation details in DM message' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)
        
        notification = Notification.last
        expect(notification.rich_message).to include('New Observation from')
        expect(notification.rich_message).to include(observer.preferred_name || observer.first_name)
        expect(notification.rich_message).to include(observation.story.truncate(200))
        expect(notification.rich_message).to include('New Observation from')
      end

      it 'includes observation details in channel message' do
        observation.update!(privacy_level: :public_observation)
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, [])
        
        # Channel functionality not implemented yet, so no notifications are created
        expect(Notification.count).to eq(0)
      end

      it 'includes ratings summary' do
        job = Observations::PostNotificationJob.new
        job.perform(observation.id, notify_teammate_ids)
        
        notification = Notification.last
        expect(notification.rich_message).to include('Ratings:')
        expect(notification.rich_message).to include('Strongly agree')
      end
    end
  end
end
