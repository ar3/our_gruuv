require 'rails_helper'

RSpec.describe SlackService do
  let(:organization) { create(:organization, :company) }
  let(:slack_service) { SlackService.new(organization) }
  let(:slack_config) { create(:slack_configuration, organization: organization) }

  before do
    slack_config
  end

  describe '#slack_configured?' do
    context 'when SLACK_BOT_TOKEN is set' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')
      end

      it 'returns true' do
        expect(slack_service.slack_configured?).to be true
      end
    end

    context 'when SLACK_BOT_TOKEN is not set' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)
        allow(organization).to receive(:slack_configured?).and_return(false)
      end

      it 'returns false' do
        expect(slack_service.slack_configured?).to be false
      end
    end
  end

  describe '#post_message' do
    let(:notification) { create(:notification, notifiable: organization, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Test message' } }], fallback_text: 'Test message') }
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when notification exists and Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123456' })
      end

      it 'posts message and updates notification status' do
        result = slack_service.post_message(notification.id)
        
        expect(mock_client).to have_received(:chat_postMessage).with(
          hash_including(
            channel: 'test-channel',
            text: 'Test message',
            blocks: notification.rich_message
          )
        )
        expect(result).to eq({ 
          success: true, 
          message_id: '1234567890.123456', 
          channel: 'test-channel', 
          response: { 'ok' => true, 'ts' => '1234567890.123456' } 
        })
        expect(notification.reload.status).to eq('sent_successfully')
        expect(notification.reload.message_id).to eq('1234567890.123456')
      end
    end

    context 'when notification has main_thread' do
      let(:main_thread) { create(:notification, notifiable: organization, message_id: '1234567890.123456') }
      let(:threaded_notification) { create(:notification, notifiable: organization, main_thread: main_thread, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Thread reply' } }], fallback_text: 'Thread reply') }

      before do
        allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123457' })
      end

      it 'posts message in thread' do
        result = slack_service.post_message(threaded_notification.id)
        
        expect(mock_client).to have_received(:chat_postMessage).with(
          hash_including(
            channel: 'test-channel',
            thread_ts: '1234567890.123456',
            text: 'Thread reply',
            blocks: threaded_notification.rich_message
          )
        )
        expect(result).to eq({ 
          success: true, 
          message_id: '1234567890.123457', 
          channel: 'test-channel', 
          response: { 'ok' => true, 'ts' => '1234567890.123457' } 
        })
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_raise(Slack::Web::Api::Errors::SlackError.new('API Error'))
      end

      it 'updates notification status to failed' do
        result = slack_service.post_message(notification.id)
        
        expect(result).to eq({ success: false, error: 'API Error', channel: 'test-channel' })
        expect(notification.reload.status).to eq('send_failed')
      end
    end

    context 'when notification does not exist' do
      it 'returns error hash' do
        result = slack_service.post_message(999999)
        expect(result).to eq({ success: false, error: 'Notification 999999 not found' })
      end
    end
  end

  describe '#update_message' do
    let(:original_notification) { create(:notification, notifiable: organization, message_id: '1234567890.123456') }
    let(:update_notification) { create(:notification, notifiable: organization, original_message: original_notification, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Updated message' } }], fallback_text: 'Updated message') }
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when notification exists and Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_update).and_return({ 'ok' => true })
      end

      it 'updates message and updates notification status' do
        result = slack_service.update_message(update_notification.id)
        
        expect(mock_client).to have_received(:chat_update).with(
          hash_including(
            channel: 'test-channel',
            ts: '1234567890.123456',
            text: 'Updated message',
            blocks: update_notification.rich_message
          )
        )
        expect(result).to eq({ 
          success: true, 
          message_id: '1234567890.123456', 
          channel: 'test-channel', 
          response: { 'ok' => true } 
        })
        expect(update_notification.reload.status).to eq('sent_successfully')
        expect(update_notification.reload.message_id).to eq('1234567890.123456')
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_update).and_raise(Slack::Web::Api::Errors::SlackError.new('API Error'))
      end

      it 'updates notification status to failed' do
        result = slack_service.update_message(update_notification.id)
        
        expect(result).to eq({ success: false, error: 'API Error', channel: 'test-channel' })
        expect(update_notification.reload.status).to eq('send_failed')
      end
    end

    context 'when notification does not exist' do
      it 'returns error hash' do
        result = slack_service.update_message(999999)
        expect(result).to eq({ success: false, error: 'Notification 999999 not found' })
      end
    end

    context 'when original message does not exist' do
      let(:update_notification) { create(:notification, notifiable: organization, original_message: nil, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Updated message' } }], fallback_text: 'Updated message') }

      it 'returns error hash' do
        result = slack_service.update_message(update_notification.id)
        expect(result).to eq({ success: false, error: 'Original message not found' })
      end
    end
  end

  describe '#test_connection' do
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when connection is successful' do
      before do
        allow(mock_client).to receive(:auth_test).and_return({ 'ok' => true, 'team' => 'Test Team', 'team_id' => 'T123456' })
      end

      it 'returns the response' do
        result = slack_service.test_connection
        expect(result).to eq({ 'ok' => true, 'team' => 'Test Team', 'team_id' => 'T123456' })
      end
    end

    context 'when connection fails' do
      before do
        allow(mock_client).to receive(:auth_test).and_raise(Slack::Web::Api::Errors::SlackError.new('Auth failed'))
      end

      it 'returns false' do
        result = slack_service.test_connection
        expect(result).to be false
      end
    end
  end



  describe '#post_test_message' do
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123456' })
    end

    context 'when Slack is configured' do
      it 'posts test message successfully' do
        result = slack_service.post_test_message('Test message')
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Test message sent successfully')
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns error message' do
        result = slack_service.post_test_message('Test message')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured')
      end
    end
  end
end 