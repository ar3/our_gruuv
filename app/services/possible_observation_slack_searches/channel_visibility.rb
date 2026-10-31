# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Classifies a Slack search.messages match as public vs private/DM/MPIM.
  # Missing flags default to private_or_dm (safer — searcher-only).
  class ChannelVisibility
    def self.classify(message)
      new(message).classify
    end

    def initialize(message)
      @message = (message || {}).with_indifferent_access
    end

    def classify
      return SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM if private_or_dm?

      SlackPossibleObservation::VISIBILITY_PUBLIC
    end

    private

    def private_or_dm?
      return true if truthy?(@message[:channel_is_mpim])
      return true if @message[:match_type].to_s == "im"
      return true if @message[:channel_id].to_s.start_with?("D")
      return true if truthy?(@message[:channel_is_private])
      return true unless visibility_fields_present?

      false
    end

    def visibility_fields_present?
      @message.key?(:channel_is_private) ||
        @message.key?(:channel_is_mpim) ||
        @message.key?(:match_type)
    end

    def truthy?(value)
      value == true || value.to_s == "true" || value.to_s == "1"
    end
  end
end
