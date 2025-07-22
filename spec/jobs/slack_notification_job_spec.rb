require 'rails_helper'

RSpec.describe SlackNotificationJob, type: :job do
  let(:huddle) { create(:huddle) }
  let(:slack_service) { instance_double(SlackService) }
  
  before do
    allow(SlackService).to receive(:new).and_return(slack_service)
  end

  describe '#perform' do
    it 'sends huddle created notification' do
      allow(slack_service).to receive(:post_huddle_notification).and_return(true)
      
      expect {
        described_class.perform_now(huddle.id, :huddle_created, creator_name: 'John Doe')
      }.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(0) # perform_now doesn't enqueue
      
      expect(slack_service).to have_received(:post_huddle_notification).with(
        huddle, 
        :huddle_created, 
        creator_name: 'John Doe'
      )
    end

    it 'sends feedback requested notification' do
      allow(slack_service).to receive(:post_huddle_notification).and_return(true)
      
      described_class.perform_now(huddle.id, :feedback_requested)
      
      expect(slack_service).to have_received(:post_huddle_notification).with(
        huddle, 
        :feedback_requested
      )
    end

    it 'handles missing huddle gracefully' do
      expect {
        described_class.perform_now(999999, :huddle_created)
      }.not_to raise_error
    end

    it 'handles Slack service errors gracefully' do
      allow(slack_service).to receive(:post_huddle_notification).and_raise(StandardError.new('Slack error'))
      
      expect {
        described_class.perform_now(huddle.id, :huddle_created)
      }.not_to raise_error
    end

    it 'returns false when notification fails' do
      allow(slack_service).to receive(:post_huddle_notification).and_return(false)
      
      result = described_class.perform_now(huddle.id, :huddle_created)
      expect(result).to be false
    end

    it 'returns true when notification succeeds' do
      allow(slack_service).to receive(:post_huddle_notification).and_return(true)
      
      result = described_class.perform_now(huddle.id, :huddle_created)
      expect(result).to be true
    end
  end
end 