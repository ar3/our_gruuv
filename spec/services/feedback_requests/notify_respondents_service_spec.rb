# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequests::NotifyRespondentsService, type: :service do
  let(:company) { create(:organization, :with_slack_config) }
  let(:requestor_teammate) { create(:company_teammate, organization: company) }
  let(:subject_teammate) { create(:company_teammate, organization: company) }
  let(:responder1) { create(:company_teammate, organization: company) }
  let(:responder2) { create(:company_teammate, organization: company) }

  let(:feedback_request) do
    create(:feedback_request,
      company: company,
      requestor_teammate: requestor_teammate,
      subject_of_feedback_teammate: subject_teammate,
      subject_line: 'Feedback about performance'
    )
  end

  before do
    create(:feedback_request_question, feedback_request: feedback_request, question_text: 'How did it go?', position: 1)
    feedback_request.feedback_request_responders.create!(teammate: responder1)
    feedback_request.feedback_request_responders.create!(teammate: responder2)
  end

  describe '#call' do
    context 'when Slack is not configured' do
      let(:company) { create(:organization) }

      it 'returns an error' do
        result = described_class.call(feedback_request: feedback_request)

        expect(result).not_to be_ok
        expect(result.error).to eq('Slack is not configured')
      end
    end

    context 'when no responders have Slack identity' do
      it 'returns ok with sent: 0' do
        result = described_class.call(feedback_request: feedback_request)

        expect(result).to be_ok
        expect(result.value[:sent]).to eq(0)
      end
    end

    context 'when some responders have Slack identity' do
      before do
        create(:teammate_identity, teammate: responder1, provider: 'slack', uid: 'U111')
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1.0' })
      end

      it 'sends DM only to responders with Slack and returns sent count' do
        result = described_class.call(feedback_request: feedback_request)

        expect(result).to be_ok
        expect(result.value[:sent]).to eq(1)
        expect(feedback_request.notifications.where(notification_type: 'feedback_request').count).to eq(1)
      end

      it 'creates notification with correct channel and message content' do
        described_class.call(feedback_request: feedback_request)

        notification = feedback_request.notifications.where(notification_type: 'feedback_request').last
        expect(notification.metadata['channel']).to eq('U111')
        expect(notification.fallback_text).to include('Respond here:')
        expect(notification.rich_message).to be_present
      end
    end

    context 'when all responders have Slack identity' do
      before do
        create(:teammate_identity, teammate: responder1, provider: 'slack', uid: 'U111')
        create(:teammate_identity, teammate: responder2, provider: 'slack', uid: 'U222')
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1.0' })
      end

      it 'sends DM to each responder and returns sent count' do
        result = described_class.call(feedback_request: feedback_request)

        expect(result).to be_ok
        expect(result.value[:sent]).to eq(2)
        expect(feedback_request.notifications.where(notification_type: 'feedback_request').count).to eq(2)
      end
    end

    context 'when SlackService fails for one responder' do
      before do
        create(:teammate_identity, teammate: responder1, provider: 'slack', uid: 'U111')
        create(:teammate_identity, teammate: responder2, provider: 'slack', uid: 'U222')
        call_count = 0
        allow_any_instance_of(SlackService).to receive(:post_message) do
          call_count += 1
          call_count == 1 ? { success: true, message_id: '1.0' } : { success: false, error: 'channel_not_found' }
        end
      end

      it 'returns error with message' do
        result = described_class.call(feedback_request: feedback_request)

        expect(result).not_to be_ok
        expect(result.error).to include('channel_not_found')
      end
    end
  end
end
