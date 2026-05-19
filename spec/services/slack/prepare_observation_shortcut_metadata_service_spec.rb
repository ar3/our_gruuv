require 'rails_helper'

RSpec.describe Slack::PrepareObservationShortcutMetadataService, type: :service do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:incoming_webhook) do
    create(:incoming_webhook, provider: 'slack', event_type: 'message_action', organization: organization)
  end
  let(:slack_service) { instance_double(SlackService) }

  let(:service) do
    described_class.new(
      organization: organization,
      incoming_webhook: incoming_webhook,
      team_id: 'T123',
      channel_id: 'C123',
      message_ts: '1234567890.123456',
      message_user_id: 'UAUTHOR',
      triggering_user_id: 'UOBSERVER',
      message_thread_ts: nil,
      payload_message_text: payload_message_text
    )
  end

  before do
    allow(SlackService).to receive(:new).with(organization).and_return(slack_service)
  end

  context 'when message text fits in metadata' do
    let(:payload_message_text) { 'Hello from Slack' }

    it 'includes full message text without prefetching' do
      expect(slack_service).not_to receive(:get_message)

      result = service.call
      expect(result).to be_ok

      meta = JSON.parse(result.value[:private_metadata_json])
      expect(meta['payload_message_text']).to eq('Hello from Slack')
      expect(meta['shortcut_incoming_webhook_id']).to eq(incoming_webhook.id)
      expect(meta).not_to have_key('payload_message_text_truncated')
    end
  end

  context 'when message text exceeds metadata limit' do
    let(:payload_message_text) { "word #{'x' * 4_000}" }

    it 'prefetches, caches on the webhook, and truncates metadata' do
      expect(slack_service).to receive(:get_message).with('C123', '1234567890.123456', thread_ts: nil).and_return(
        success: true,
        text: payload_message_text
      )

      result = service.call
      expect(result).to be_ok

      incoming_webhook.reload
      expect(incoming_webhook.cached_slack_message_text).to eq(payload_message_text)

      meta = JSON.parse(result.value[:private_metadata_json])
      expect(meta['payload_message_text_truncated']).to be true
      expect(meta['slack_message_prefetch_attempted']).to be true
      expect(meta['slack_message_prefetch_succeeded']).to be true
      expect(meta['payload_message_text'].length).to be < payload_message_text.length
      expect(result.value[:private_metadata_json].bytesize).to be <= Slack::ObservationShortcutMetadata::PRIVATE_METADATA_LIMIT
    end

    it 'truncates metadata when prefetch fails' do
      expect(slack_service).to receive(:get_message).and_return(success: false, error: 'not_in_channel')

      result = service.call
      expect(result).to be_ok

      incoming_webhook.reload
      expect(incoming_webhook.cached_slack_message_text).to be_nil

      meta = JSON.parse(result.value[:private_metadata_json])
      expect(meta['slack_message_prefetch_succeeded']).to be false
      expect(meta['payload_message_text']).to be_present
    end
  end
end
