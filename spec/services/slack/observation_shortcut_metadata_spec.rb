require 'rails_helper'

RSpec.describe Slack::ObservationShortcutMetadata do
  let(:base) do
    {
      team_id: 'T123',
      channel_id: 'C123',
      message_ts: '1234567890.123456',
      message_user_id: 'UAUTHOR',
      triggering_user_id: 'UOBSERVER'
    }
  end
  let(:shortcut_id) { 42 }

  describe '.fits?' do
    it 'returns true when metadata is under the limit' do
      expect(described_class.fits?(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id,
        message_text: 'Short message'
      )).to be true
    end

    it 'returns false when message text makes metadata exceed the limit' do
      long_text = 'x' * 4_000
      expect(described_class.fits?(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id,
        message_text: long_text
      )).to be false
    end
  end

  describe '.truncate_text_at_boundary' do
    it 'does not split a Slack user mention' do
      text = 'Hello <@U123ABC456> there'
      truncated = described_class.send(:truncate_text_at_boundary, text, 10)
      expect(truncated).to eq('Hello ')
      expect(truncated).not_to include('<@U')
    end
  end

  describe '.fit_message_text' do
    it 'returns full text when it fits' do
      text, json, truncated = described_class.fit_message_text(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id,
        message_text: 'Hello world'
      )

      expect(text).to eq('Hello world')
      expect(truncated).to be false
      expect(json.bytesize).to be <= described_class::PRIVATE_METADATA_LIMIT
    end

    it 'returns truncated text that fits in metadata' do
      long_text = "Line\n" * 800
      text, json, truncated = described_class.fit_message_text(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id,
        message_text: long_text,
        slack_message_prefetch_attempted: true,
        slack_message_prefetch_succeeded: false
      )

      expect(truncated).to be true
      expect(text.length).to be < long_text.length
      expect(json.bytesize).to be <= described_class::PRIVATE_METADATA_LIMIT
      expect(JSON.parse(json)['payload_message_text_truncated']).to be true
    end
  end
end
