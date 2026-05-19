require 'rails_helper'

RSpec.describe Slack::ResolveObservationMessageTextService, type: :service do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:shortcut_webhook) do
    create(:incoming_webhook, provider: 'slack', event_type: 'message_action', organization: organization,
           cached_slack_message_text: 'Full cached body')
  end

  def resolve(**overrides)
    described_class.new(
      organization: organization,
      shortcut_incoming_webhook_id: shortcut_webhook.id,
      payload_message_text: 'Truncated snippet',
      payload_message_text_truncated: true,
      slack_message_prefetch_attempted: true,
      slack_message_prefetch_succeeded: false,
      channel_id: 'C123',
      message_ts: '1234567890.123456',
      message_thread_ts: nil,
      **overrides
    ).call
  end

  it 'prefers cached text from the shortcut webhook' do
    result = resolve
    expect(result).to be_ok
    expect(result.value.text).to eq('Full cached body')
    expect(result.value.partial).to be false
  end

  it 'uses metadata text when cache is empty and marks partial when prefetch failed' do
    shortcut_webhook.update!(cached_slack_message_text: nil)

    result = resolve
    expect(result).to be_ok
    expect(result.value.text).to eq('Truncated snippet')
    expect(result.value.partial).to be true
  end

  it 'does not call Slack API when prefetch was already attempted' do
    shortcut_webhook.update!(cached_slack_message_text: nil)

    expect(SlackService).not_to receive(:new)

    result = resolve(payload_message_text: nil)
    expect(result).to be_ok
    expect(result.value.text).to be_nil
  end

  it 'calls Slack API when prefetch was not attempted' do
    slack_service = instance_double(SlackService)
    allow(SlackService).to receive(:new).with(organization).and_return(slack_service)
    expect(slack_service).to receive(:get_message).and_return(success: true, text: 'From API')

    result = resolve(
      shortcut_incoming_webhook_id: nil,
      payload_message_text: nil,
      payload_message_text_truncated: false,
      slack_message_prefetch_attempted: false,
      slack_message_prefetch_succeeded: false
    )

    expect(result.value.text).to eq('From API')
    expect(result.value.partial).to be false
  end
end
