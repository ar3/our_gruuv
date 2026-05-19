# Resolves Slack message body when creating an observation from the shortcut modal.
module Slack
  class ResolveObservationMessageTextService
    MessageTextResolution = Data.define(:text, :partial)

    def initialize(organization:, shortcut_incoming_webhook_id:, payload_message_text:,
                   payload_message_text_truncated:, slack_message_prefetch_attempted:,
                   slack_message_prefetch_succeeded:, channel_id:, message_ts:, message_thread_ts: nil)
      @organization = organization
      @shortcut_incoming_webhook_id = shortcut_incoming_webhook_id
      @payload_message_text = payload_message_text
      @payload_message_text_truncated = payload_message_text_truncated
      @slack_message_prefetch_attempted = slack_message_prefetch_attempted
      @slack_message_prefetch_succeeded = slack_message_prefetch_succeeded
      @channel_id = channel_id
      @message_ts = message_ts
      @message_thread_ts = message_thread_ts
    end

    def call
      cached = cached_message_text
      return Result.ok(MessageTextResolution.new(text: cached, partial: false)) if cached.present?

      metadata_text = @payload_message_text.to_s.strip.presence
      if metadata_text.present?
        partial = @payload_message_text_truncated &&
                  @slack_message_prefetch_attempted &&
                  !@slack_message_prefetch_succeeded
        return Result.ok(MessageTextResolution.new(text: metadata_text, partial: partial))
      end

      unless @slack_message_prefetch_attempted
        api_text = fetch_via_api
        return Result.ok(MessageTextResolution.new(text: api_text, partial: false)) if api_text.present?
      end

      Result.ok(MessageTextResolution.new(text: nil, partial: false))
    end

    private

    def cached_message_text
      return nil unless @shortcut_incoming_webhook_id.present?

      IncomingWebhook.find_by(id: @shortcut_incoming_webhook_id)&.cached_slack_message_text&.presence
    end

    def fetch_via_api
      result = SlackService.new(@organization).get_message(
        @channel_id,
        @message_ts,
        thread_ts: @message_thread_ts
      )
      result[:success] ? result[:text].to_s.presence : nil
    rescue StandardError => e
      Rails.logger.warn "Slack observation submit: get_message failed - #{e.message}"
      nil
    end
  end
end
