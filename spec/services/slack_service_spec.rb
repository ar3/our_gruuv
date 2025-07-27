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

      it 'calls post_feedback_in_thread for post_feedback_in_thread type' do
        allow(slack_service).to receive(:post_feedback_in_thread).and_return(true)
        result = slack_service.post_huddle_notification(huddle, :post_feedback_in_thread, feedback_id: 123)
        expect(slack_service).to have_received(:post_feedback_in_thread).with(huddle, 123)
        expect(result).to be true
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

  describe '#post_feedback_in_thread' do
    let(:feedback) { create(:huddle_feedback) }
    let(:announcement_notification) { create(:notification, notifiable: huddle, notification_type: 'huddle_announcement', status: 'sent_successfully', message_id: '1234567890.123456', metadata: { channel: 'test-channel' }) }
    
    before do
      allow(huddle).to receive(:slack_announcement_notification).and_return(announcement_notification)
      allow(huddle).to receive(:slack_channel).and_return('#test-channel')
      allow(huddle.huddle_feedbacks).to receive(:find_by).with(id: feedback.id).and_return(feedback)
      allow(slack_service).to receive(:post_message).and_return({ 'ok' => true })
      allow(slack_service).to receive(:post_huddle_start_announcement).and_return({ 'ok' => true })
      allow(slack_service).to receive(:post_huddle_summary).and_return({ 'ok' => true })
    end

    it 'posts feedback in thread when announcement exists' do
      result = slack_service.post_feedback_in_thread(huddle, feedback.id)
      
      expect(slack_service).to have_received(:post_message).with(
        channel: '#test-channel',
        thread_ts: '1234567890.123456',
        blocks: kind_of(Array)
      )
      expect(result).to eq({ 'ok' => true })
    end

    it 'creates announcement and summary when none exist' do
      allow(huddle).to receive(:slack_announcement_notification).and_return(nil, announcement_notification)
      
      result = slack_service.post_feedback_in_thread(huddle, feedback.id)
      
      expect(slack_service).to have_received(:post_huddle_start_announcement).with(huddle)
      expect(slack_service).to have_received(:post_huddle_summary).with(huddle)
      expect(result).to eq({ 'ok' => true })
    end

    it 'returns false when feedback not found' do
      allow(huddle.huddle_feedbacks).to receive(:find_by).with(id: feedback.id).and_return(nil)
      
      result = slack_service.post_feedback_in_thread(huddle, feedback.id)
      expect(result).to be false
    end
  end




end 