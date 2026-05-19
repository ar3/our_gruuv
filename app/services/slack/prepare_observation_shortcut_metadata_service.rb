# Prepares views.open private_metadata for the create-observation Slack shortcut.
# When message text exceeds Slack's 3000-char metadata limit, truncates for the modal and
# synchronously prefetches the full message onto the shortcut IncomingWebhook when possible.
module Slack
  class PrepareObservationShortcutMetadataService
    def initialize(organization:, incoming_webhook:, team_id:, channel_id:, message_ts:,
                   message_user_id:, triggering_user_id:, message_thread_ts: nil, payload_message_text: nil)
      @organization = organization
      @incoming_webhook = incoming_webhook
      @team_id = team_id
      @channel_id = channel_id
      @message_ts = message_ts
      @message_user_id = message_user_id
      @triggering_user_id = triggering_user_id
      @message_thread_ts = message_thread_ts
      @payload_message_text = payload_message_text
      @slack_service = SlackService.new(organization)
    end

    def call
      base = {
        team_id: @team_id,
        channel_id: @channel_id,
        message_ts: @message_ts,
        message_user_id: @message_user_id,
        triggering_user_id: @triggering_user_id
      }
      base[:message_thread_ts] = @message_thread_ts if @message_thread_ts.present?

      shortcut_id = @incoming_webhook.id
      fallback_metadata_json = ObservationShortcutMetadata.to_json(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id
      )

      unless @payload_message_text.present?
        return Result.ok(
          private_metadata_json: fallback_metadata_json,
          fallback_metadata_json: fallback_metadata_json
        )
      end

      if ObservationShortcutMetadata.fits?(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id,
        message_text: @payload_message_text
      )
        return Result.ok(
          private_metadata_json: ObservationShortcutMetadata.to_json(
            base: base,
            shortcut_incoming_webhook_id: shortcut_id,
            message_text: @payload_message_text
          ),
          fallback_metadata_json: fallback_metadata_json
        )
      end

      prefetch_succeeded = prefetch_and_cache_message_text
      _fitted_text, private_metadata_json, _truncated = ObservationShortcutMetadata.fit_message_text(
        base: base,
        shortcut_incoming_webhook_id: shortcut_id,
        message_text: @payload_message_text,
        slack_message_prefetch_attempted: true,
        slack_message_prefetch_succeeded: prefetch_succeeded
      )

      Result.ok(
        private_metadata_json: private_metadata_json,
        fallback_metadata_json: fallback_metadata_json,
        truncated: true,
        prefetch_succeeded: prefetch_succeeded
      )
    end

    private

    def prefetch_and_cache_message_text
      result = @slack_service.get_message(@channel_id, @message_ts, thread_ts: @message_thread_ts)
      if result[:success] && result[:text].present?
        @incoming_webhook.update!(cached_slack_message_text: result[:text])
        true
      else
        false
      end
    rescue StandardError => e
      Rails.logger.warn "Slack observation shortcut: prefetch message failed - #{e.message}"
      false
    end
  end
end
