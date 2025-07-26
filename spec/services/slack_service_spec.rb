require 'rails_helper'

RSpec.describe SlackService, type: :service do
  let(:slack_service) { SlackService.new }
  let(:huddle) { create(:huddle) }
  
  describe '#slack_configured?' do
    context 'when SLACK_BOT_TOKEN is set' do
      before do
        @original_token = ENV['SLACK_BOT_TOKEN']
        ENV['SLACK_BOT_TOKEN'] = 'xoxb-test-token'
      end
      
      after do
        ENV['SLACK_BOT_TOKEN'] = @original_token
      end
      
      it 'returns true' do
        expect(slack_service.send(:slack_configured?)).to be true
      end
    end
    
    context 'when SLACK_BOT_TOKEN is not set' do
      before do
        @original_token = ENV['SLACK_BOT_TOKEN']
        ENV['SLACK_BOT_TOKEN'] = nil
      end
      
      after do
        ENV['SLACK_BOT_TOKEN'] = @original_token
      end
      
      it 'returns false' do
        expect(slack_service.send(:slack_configured?)).to be false
      end
    end
  end
  
  describe '#post_huddle_notification' do
    context 'when huddle is present' do
      before do
        allow(huddle).to receive(:display_name).and_return('Test Huddle')
        allow(huddle).to receive(:facilitator_names).and_return(['John Doe'])
        allow(huddle).to receive(:participation_rate).and_return(75)
        allow(huddle).to receive(:nat_20_score).and_return(15.5)
        allow(huddle).to receive(:slack_channel).and_return('#test-channel')
      end
      
      it 'returns false when Slack is not configured' do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
        result = slack_service.post_huddle_notification(huddle, :huddle_created)
        expect(result).to be false
      end
      
      it 'returns false for unknown notification type' do
        result = slack_service.post_huddle_notification(huddle, :unknown_type)
        expect(result).to be false
      end
    end
    
    context 'when huddle is not present' do
      it 'returns false' do
        result = slack_service.post_huddle_notification(nil, :huddle_created)
        expect(result).to be false
      end
    end
  end
  
  describe 'message templates' do
    it 'has the expected notification types' do
      expected_types = [:huddle_created, :huddle_started, :huddle_reminder, :feedback_requested, :huddle_completed]
      expected_types.each do |type|
        expect(SlackConstants::MESSAGE_TEMPLATES[type]).to be_present
      end
    end
    
    it 'formats huddle_created message correctly' do
      template = SlackConstants::MESSAGE_TEMPLATES[:huddle_created]
      message = template % {
        huddle_name: 'Test Huddle',
        creator_name: 'John Doe'
      }
      expect(message).to include('Test Huddle')
      expect(message).to include('John Doe')
    end
  end

  describe '.slack_announcement_url' do
    let(:slack_config) { create(:slack_configuration, workspace_subdomain: 'test-workspace') }

    it 'returns nil when workspace_subdomain is missing' do
      slack_config.update(workspace_subdomain: nil)
      result = SlackService.slack_announcement_url(
        slack_configuration: slack_config,
        channel_name: '#general',
        message_id: '1234567890.123456'
      )
      expect(result).to be_nil
    end

    it 'returns nil when channel_name is missing' do
      result = SlackService.slack_announcement_url(
        slack_configuration: slack_config,
        channel_name: nil,
        message_id: '1234567890.123456'
      )
      expect(result).to be_nil
    end

    it 'returns nil when message_id is missing' do
      result = SlackService.slack_announcement_url(
        slack_configuration: slack_config,
        channel_name: '#general',
        message_id: nil
      )
      expect(result).to be_nil
    end

    it 'returns correct URL when all parameters are present' do
      result = SlackService.slack_announcement_url(
        slack_configuration: slack_config,
        channel_name: '#general',
        message_id: '1234567890.123456'
      )
      expected_url = 'https://test-workspace.slack.com/archives/general/p1234567890123456'
      expect(result).to eq(expected_url)
    end

    it 'handles channel names with and without #' do
      result_with_hash = SlackService.slack_announcement_url(
        slack_configuration: slack_config,
        channel_name: '#engineering',
        message_id: '1234567890.123456'
      )
      result_without_hash = SlackService.slack_announcement_url(
        slack_configuration: slack_config,
        channel_name: 'engineering',
        message_id: '1234567890.123456'
      )
      
      expected_url = 'https://test-workspace.slack.com/archives/engineering/p1234567890123456'
      expect(result_with_hash).to eq(expected_url)
      expect(result_without_hash).to eq(expected_url)
    end
  end
end 