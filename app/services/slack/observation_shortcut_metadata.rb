# Builds private_metadata for the "create observation from message" Slack modal.
# Slack limits private_metadata to 3000 characters (views.open).
module Slack
  class ObservationShortcutMetadata
    PRIVATE_METADATA_LIMIT = 3000
    SLACK_USER_MENTION_PATTERN = /<@(U[A-Z0-9]+)>/

    def self.build(base:, shortcut_incoming_webhook_id:, message_text: nil, truncated: false,
                   slack_message_prefetch_attempted: false, slack_message_prefetch_succeeded: nil)
      meta = base.stringify_keys.compact
      meta['shortcut_incoming_webhook_id'] = shortcut_incoming_webhook_id
      meta['payload_message_text_truncated'] = true if truncated
      if slack_message_prefetch_attempted
        meta['slack_message_prefetch_attempted'] = true
        meta['slack_message_prefetch_succeeded'] = slack_message_prefetch_succeeded == true
      end
      meta['payload_message_text'] = message_text if message_text.present?
      meta
    end

    def self.to_json(**kwargs)
      build(**kwargs).to_json
    end

    def self.json_byte_size(**kwargs)
      to_json(**kwargs).bytesize
    end

    def self.fits?(**kwargs)
      json_byte_size(**kwargs) <= PRIVATE_METADATA_LIMIT
    end

    # Truncate so JSON fits the limit; sets truncated + optional prefetch flags when needed.
    def self.fit_message_text(base:, shortcut_incoming_webhook_id:, message_text:,
                              slack_message_prefetch_attempted: false, slack_message_prefetch_succeeded: nil)
      text = message_text.to_s

      if fits?(
        base: base,
        shortcut_incoming_webhook_id: shortcut_incoming_webhook_id,
        message_text: text,
        truncated: false
      )
        return [text, to_json(
          base: base,
          shortcut_incoming_webhook_id: shortcut_incoming_webhook_id,
          message_text: text
        ), false]
      end

      low = 0
      high = text.length
      best_text = +''
      best_json = nil

      while low <= high
        mid = (low + high) / 2
        candidate = truncate_text_at_boundary(text, mid)
        candidate_json = to_json(
          base: base,
          shortcut_incoming_webhook_id: shortcut_incoming_webhook_id,
          message_text: candidate.presence,
          truncated: true,
          slack_message_prefetch_attempted: slack_message_prefetch_attempted,
          slack_message_prefetch_succeeded: slack_message_prefetch_succeeded
        )

        if candidate_json.bytesize <= PRIVATE_METADATA_LIMIT
          best_text = candidate
          best_json = candidate_json
          low = mid + 1
        else
          high = mid - 1
        end
      end

      best_json ||= to_json(
        base: base,
        shortcut_incoming_webhook_id: shortcut_incoming_webhook_id,
        message_text: nil,
        truncated: true,
        slack_message_prefetch_attempted: slack_message_prefetch_attempted,
        slack_message_prefetch_succeeded: slack_message_prefetch_succeeded
      )

      [best_text.presence, best_json, true]
    end

    # Avoid splitting Slack user mentions (<@U…>).
    def self.truncate_text_at_boundary(text, max_chars)
      return text if max_chars >= text.length

      slice = text[0, max_chars]
      mention_start = slice.rindex('<@')
      return slice unless mention_start

      tail = slice[mention_start..]
      return slice if tail.match?(SLACK_USER_MENTION_PATTERN)

      slice[0, mention_start]
    end

    private_class_method :truncate_text_at_boundary
  end
end
