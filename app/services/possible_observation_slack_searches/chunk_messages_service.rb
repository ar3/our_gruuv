# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Formats raw Slack messages into overlapping text chunks for Bedrock.
  class ChunkMessagesService
    MESSAGES_PER_CHUNK = 40
    OVERLAP_MESSAGES = 3

    def self.call(messages)
      new(messages).call
    end

    def initialize(messages)
      @messages = Array(messages)
    end

    def call
      return [""] if @messages.empty?
      return [format_chunk(@messages)] if @messages.size <= MESSAGES_PER_CHUNK

      chunks = []
      i = 0
      while i < @messages.size
        slice = @messages[i, MESSAGES_PER_CHUNK]
        chunks << format_chunk(slice)
        break if i + MESSAGES_PER_CHUNK >= @messages.size

        i += MESSAGES_PER_CHUNK - OVERLAP_MESSAGES
      end
      chunks
    end

    private

    def format_chunk(messages)
      messages.map { |message| format_message(message) }.join("\n\n---\n\n")
    end

    def format_message(message)
      m = message.with_indifferent_access
      header = [
        "channel_id=#{m[:channel_id]}",
        "channel_name=#{m[:channel_name]}",
        "user=#{m[:user]}",
        "username=#{m[:username]}",
        "ts=#{m[:ts]}",
        "permalink=#{m[:permalink]}"
      ].join(" ")
      "[#{header}]\n#{m[:text]}"
    end
  end
end
