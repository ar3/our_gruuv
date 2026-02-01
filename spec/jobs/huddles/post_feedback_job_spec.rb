require 'rails_helper'

RSpec.describe Huddles::PostFeedbackJob, type: :job do
  let(:organization) { create(:organization, name: 'Test Org') }
  let!(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:team) { create(:team, company: organization) }
  let(:slack_channel) { create(:third_party_object, organization: organization, third_party_source: 'slack', third_party_object_type: 'channel', third_party_id: 'C123', display_name: '#general') }
  let(:huddle) { create(:huddle, team: team, started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:participant) { create(:huddle_participant, huddle: huddle, teammate: teammate, role: 'active') }
  let(:feedback) { create(:huddle_feedback, huddle: huddle, teammate: teammate) }

  before do
    # Set up huddle channel for the team
    team.third_party_object_associations.create!(
      third_party_object: slack_channel,
      association_type: 'huddle_channel'
    )

    # Mock SlackService to avoid actual API calls
    allow_any_instance_of(SlackService).to receive(:post_message).and_return({
      success: true,
      message_id: '1234567890.123456',
      channel: '#test-channel'
    })
    allow_any_instance_of(SlackService).to receive(:update_message).and_return({
      success: true,
      message_id: '1234567890.123456',
      channel: '#test-channel'
    })
  end

  describe '#perform' do
    context 'when Slack is configured' do
      it 'creates announcement and summary first if none exist' do
        expect(Huddles::PostAnnouncementJob).to receive(:perform_now).with(huddle.id)
        expect(Huddles::PostSummaryJob).to receive(:perform_now).with(huddle.id)
        
        described_class.perform_and_get_result(huddle.id, feedback.id)
      end

      it 'creates a new feedback notification' do
        # Create announcement first
        create(:notification, 
          notifiable: huddle,
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          metadata: { channel: huddle.slack_channel }
        )

        expect {
          described_class.perform_and_get_result(huddle.id, feedback.id)
        }.to change { huddle.notifications.feedbacks.count }.by(1)

        notification = huddle.notifications.feedbacks.last
        expect(notification.notification_type).to eq('huddle_feedback')
        expect(notification.status).to eq('preparing_to_send')
        expect(notification.metadata['channel']).to eq(huddle.slack_channel)
        expect(notification.main_thread).to be_present
      end

      it 'calls SlackService to post the message' do
        # Create announcement first
        create(:notification, 
          notifiable: huddle,
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          metadata: { channel: huddle.slack_channel }
        )

        slack_service = instance_double(SlackService)
        allow(SlackService).to receive(:new).with(anything).and_return(slack_service)
        expect(slack_service).to receive(:post_message).with(kind_of(Integer)).and_return({
          success: true,
          message_id: '1234567890.123456'
        })

        described_class.perform_and_get_result(huddle.id, feedback.id)
      end

      it 'returns success result when posting succeeds' do
        # Create announcement first
        create(:notification, 
          notifiable: huddle,
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          metadata: { channel: huddle.slack_channel }
        )

        result = described_class.perform_and_get_result(huddle.id, feedback.id)
        
        expect(result).to include(
          success: true,
          action: 'posted_feedback',
          huddle_id: huddle.id,
          feedback_id: feedback.id
        )
        expect(result).to have_key(:notification_id)
        expect(result).to have_key(:message_id)
      end
    end

    context 'when Slack is not configured' do
      let(:unconfigured_team) { create(:team, company: organization) }
      let(:unconfigured_huddle) { create(:huddle, team: unconfigured_team, started_at: Time.current) }
      # Reuse the existing teammate since person is already a teammate in this organization
      let(:unconfigured_feedback) { create(:huddle_feedback, huddle: unconfigured_huddle, teammate: teammate) }

      it 'returns error result without creating notification' do
        expect {
          described_class.perform_and_get_result(unconfigured_huddle.id, unconfigured_feedback.id)
        }.not_to change { unconfigured_huddle.notifications.count }

        result = described_class.perform_and_get_result(unconfigured_huddle.id, unconfigured_feedback.id)

        expect(result).to include(
          success: false
        )
        expect(result[:error]).to include("Slack huddle channel not configured")
      end
    end

    context 'when huddle does not exist' do
      it 'returns error result' do
        result = described_class.perform_and_get_result(99999, feedback.id)
        
        expect(result).to include(
          success: false,
          error: "Record not found: Couldn't find Huddle with 'id'=99999"
        )
      end
    end

    context 'when feedback does not exist' do
      it 'returns error result' do
        result = described_class.perform_and_get_result(huddle.id, 99999)
        
        expect(result).to include(
          success: false,
          error: "Record not found: Couldn't find HuddleFeedback with 'id'=99999"
        )
      end
    end

    context 'when SlackService fails' do
      before do
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({
          success: false,
          error: 'Slack API error'
        })
      end

      it 'returns error result' do
        # Create announcement first
        create(:notification, 
          notifiable: huddle,
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          metadata: { channel: huddle.slack_channel }
        )

        result = described_class.perform_and_get_result(huddle.id, feedback.id)
        
        expect(result).to include(
          success: false,
          action: 'post_feedback_failed',
          huddle_id: huddle.id,
          feedback_id: feedback.id,
          error: 'Slack API error'
        )
        expect(result).to have_key(:notification_id)
      end
    end
  end

  describe 'perform_now execution' do
    it 'actually executes the job when called with perform_now' do
      # Create announcement first
      create(:notification, 
        notifiable: huddle,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        metadata: { channel: huddle.slack_channel }
      )

      # This test ensures perform_now actually runs the job
      expect {
        described_class.perform_and_get_result(huddle.id, feedback.id)
      }.to change { huddle.notifications.count }.by(1)
    end

    it 'logs execution information' do
      # Create announcement first
      create(:notification, 
        notifiable: huddle,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        metadata: { channel: huddle.slack_channel }
      )

      expect(Rails.logger).to receive(:info).with(/Posting feedback for huddle #{huddle.id}, feedback #{feedback.id}/)
      
      described_class.perform_and_get_result(huddle.id, feedback.id)
    end
  end
end 