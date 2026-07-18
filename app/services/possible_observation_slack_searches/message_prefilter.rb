# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Drops very short Slack messages before LLM chunking. Raw search file is unchanged.
  class MessagePrefilter
    MIN_TEXT_CHARS = 40

    def self.call(messages)
      new(messages).call
    end

    def initialize(messages)
      @messages = Array(messages)
    end

    def call
      @messages.select { |message| keep?(message) }
    end

    private

    def keep?(message)
      text = message.with_indifferent_access[:text].to_s
      text.gsub(/\s+/, " ").strip.length >= MIN_TEXT_CHARS
    end
  end
end
