require 'rails_helper'

RSpec.describe SlackController, type: :controller do
  let(:slack_service) { instance_double(SlackService) }
  
  before do
    allow(SlackService).to receive(:new).and_return(slack_service)
  end

  describe 'GET #test_connection' do
    context 'when Slack is configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')
      end

      it 'returns success when connection test passes' do
        test_result = {
          'team' => 'Test Team',
          'team_id' => 'T123456',
          'user_id' => 'U123456',
          'user' => 'test-bot'
        }
        allow(slack_service).to receive(:test_connection).and_return(test_result)

        get :test_connection, params: { organization_id: 1 }
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['team']).to eq('Test Team')
        expect(json_response['team_id']).to eq('T123456')
      end

      it 'returns error when connection test fails' do
        allow(slack_service).to receive(:test_connection).and_return(false)

        get :test_connection, params: { organization_id: 1 }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Failed to connect to Slack')
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)
      end

      it 'returns configuration error' do
        get :test_connection, params: { organization_id: 1 }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Slack not configured for this organization')
      end
    end
  end

  describe 'GET #list_channels' do
    context 'when Slack is configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')
      end

      it 'returns list of channels' do
        channels = [
          { 'id' => 'C123', 'name' => 'general', 'is_private' => false },
          { 'id' => 'C456', 'name' => 'random', 'is_private' => false }
        ]
        allow(slack_service).to receive(:list_channels).and_return(channels)

        get :list_channels, params: { organization_id: 1 }
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['channels'].length).to eq(2)
        expect(json_response['channels'].first['name']).to eq('general')
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)
      end

      it 'returns configuration error' do
        get :list_channels, params: { organization_id: 1 }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Slack not configured for this organization')
      end
    end
  end

  describe 'POST #post_test_message' do
    context 'when Slack is configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')
      end

      it 'posts test message successfully' do
        post_result = {
          'ts' => '1234567890.123456',
          'channel' => '#test-channel'
        }
        allow(slack_service).to receive(:post_message).and_return(post_result)

        post :post_test_message, params: { organization_id: 1, channel: '#test-channel', message: 'Test message' }
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Test message posted successfully')
        expect(json_response['timestamp']).to eq('1234567890.123456')
      end

      it 'uses default channel and message when not provided' do
        post_result = { 'ts' => '1234567890.123456', 'channel' => '#general' }
        allow(slack_service).to receive(:post_message).and_return(post_result)

        post :post_test_message, params: { organization_id: 1 }
        expect(response).to have_http_status(:ok)
        
        expect(slack_service).to have_received(:post_message).with(
          channel: nil,
          text: "🧪 Test message from Our Gruuv Huddle Bot!"
        )
      end

      it 'returns error when message posting fails' do
        allow(slack_service).to receive(:post_message).and_return(false)

        post :post_test_message, params: { organization_id: 1 }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Failed to post test message')
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)
      end

      it 'returns configuration error' do
        post :post_test_message, params: { organization_id: 1 }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Slack not configured for this organization')
      end
    end
  end

  describe 'GET #configuration_status' do
    it 'returns configuration status' do
      allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')

      get :configuration_status
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['bot_token_configured']).to be true
      expect(json_response['default_channel']).to eq(SlackConstants::DEFAULT_HUDDLE_CHANNEL)
      expect(json_response['bot_username']).to eq(SlackConstants::BOT_USERNAME)
      expect(json_response['bot_emoji']).to eq(SlackConstants::BOT_EMOJI)
    end

    it 'shows bot token as not configured when missing' do
      allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)

      get :configuration_status
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['bot_token_configured']).to be false
    end
  end
end 