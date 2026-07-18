# frozen_string_literal: true

module PossibleObservationSlackSearches
  # After Slack fetch: pre-filter, newest-first, materialize ≤500-message consultation batches.
  class CreateMessageBatches
    MESSAGES_PER_BATCH = 500

    def self.call(search:)
      new(search: search).call
    end

    def initialize(search:)
      @search = search
    end

    def call
      filtered = MessagePrefilter.call(@search.raw_messages)
      sorted = filtered.sort_by { |message| -message.with_indifferent_access[:ts].to_f }

      @search.message_batches.destroy_all
      @search.update!(filtered_messages_count: sorted.size)

      return [] if sorted.empty?

      sorted.each_slice(MESSAGES_PER_BATCH).with_index(1).map do |slice, position|
        keys = slice.map { |message| PossibleObservationSlackSearchBatch.message_key(message) }
        ts_values = slice.map { |message| message.with_indifferent_access[:ts].to_s }
        @search.message_batches.create!(
          position: position,
          message_keys: keys,
          messages_count: slice.size,
          newest_ts: ts_values.first,
          oldest_ts: ts_values.last,
          extraction_status: "ready",
          extractions: {}
        )
      end
    end
  end
end
