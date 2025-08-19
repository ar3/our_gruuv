require 'rails_helper'

RSpec.describe Huddles::PostAnnouncementJob, type: :job do
  let(:organization) { create(:organization, name: 'Test Org') }
  let!(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }
  
  # Test huddle with 0 participants
  let(:empty_huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: Time.current) }

  before do
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
      it 'creates a new announcement notification when none exists' do
        expect {
          described_class.perform_and_get_result(huddle.id)
        }.to change { huddle.notifications.announcements.count }.by(1)

        notification = huddle.notifications.announcements.last
        expect(notification.notification_type).to eq('huddle_announcement')
        expect(notification.status).to eq('preparing_to_send')
        expect(notification.metadata['channel']).to eq(huddle.slack_channel)
      end

      it 'calls SlackService to post the message' do
        slack_service = instance_double(SlackService)
        allow(SlackService).to receive(:new).with(anything).and_return(slack_service)
        expect(slack_service).to receive(:post_message).with(kind_of(Integer)).and_return({
          success: true,
          message_id: '1234567890.123456'
        })

        described_class.perform_and_get_result(huddle.id)
      end

      it 'returns success result when posting succeeds' do
        result = described_class.perform_and_get_result(huddle.id)
        
        expect(result).to include(
          success: true,
          action: 'posted',
          huddle_id: huddle.id
        )
        expect(result).to have_key(:notification_id)
        expect(result).to have_key(:message_id)
      end

      it 'updates existing announcement when one exists' do
        # Create an existing announcement
        existing_notification = create(:notification, 
          notifiable: huddle,
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          metadata: { channel: huddle.slack_channel }
        )

        expect {
          described_class.perform_and_get_result(huddle.id)
        }.to change { huddle.notifications.announcements.count }.by(1)

        # Should create a new notification for the update
        new_notification = huddle.notifications.announcements.last
        expect(new_notification.original_message).to eq(existing_notification)
      end

      it 'returns success result when updating succeeds' do
        # Create an existing announcement
        create(:notification, 
          notifiable: huddle,
          notification_type: 'huddle_announcement',
          status: 'sent_successfully',
          metadata: { channel: huddle.slack_channel }
        )

        result = described_class.perform_and_get_result(huddle.id)
        
        expect(result).to include(
          success: true,
          action: 'updated',
          huddle_id: huddle.id
        )
        expect(result).to have_key(:notification_id)
        expect(result).to have_key(:message_id)
      end
    end

    context 'when Slack is not configured' do
      before do
        slack_config.destroy!
      end

      it 'returns error result without creating notification' do
        expect {
          described_class.perform_and_get_result(huddle.id)
        }.not_to change { huddle.notifications.count }

        result = described_class.perform_and_get_result(huddle.id)
        
        expect(result).to include(
          success: false,
          error: "Slack not configured for organization #{organization.id}"
        )
      end
    end

    context 'when huddle does not exist' do
      it 'returns error result' do
        result = described_class.perform_and_get_result(99999)
        
        expect(result).to include(
          success: false,
          error: "Huddle with ID 99999 not found"
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
        result = described_class.perform_and_get_result(huddle.id)
        
        expect(result).to include(
          success: false,
          action: 'post_failed',
          huddle_id: huddle.id,
          error: 'Slack API error'
        )
        expect(result).to have_key(:notification_id)
      end
    end
  end

  describe 'announcement states' do
    it 'handles huddle with 0 participants correctly' do
      result = described_class.perform_and_get_result(empty_huddle.id)
      
      expect(result).to include(
        success: true,
        action: 'posted',
        huddle_id: empty_huddle.id
      )
      
      # Verify the notification was created with appropriate content
      notification = empty_huddle.notifications.announcements.last
      expect(notification).to be_present
      expect(notification.rich_message).to be_present
      
      # Check that the blocks contain appropriate text for 0 participants
      blocks = notification.rich_message
      expect(blocks).to be_an(Array)
      
      # Find the header block
      header_block = blocks.find { |block| block["type"] == 'header' }
      expect(header_block).to be_present
      expect(header_block["text"]["text"]).to include('New Huddle Starting!')
      
      # Find the section block
      section_block = blocks.find { |block| block["type"] == 'section' }
      expect(section_block).to be_present
      expect(section_block["text"]["text"]).to include('Be the first to join')
    end
  end

  describe 'perform_now execution' do
    it 'actually executes the job when called with perform_now' do
      # This test ensures perform_now actually runs the job
      expect {
        described_class.perform_and_get_result(huddle.id)
      }.to change { huddle.notifications.count }.by(1)
    end

    it 'logs execution information' do
      expect(Rails.logger).to receive(:info).with(/Creating new announcement for huddle #{huddle.id}/)
      
      described_class.perform_and_get_result(huddle.id)
    end
  end
end 