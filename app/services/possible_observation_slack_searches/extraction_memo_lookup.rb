# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Splits batch messages into memo hits (reuse raw LLM items) vs misses (need LLM).
  class ExtractionMemoLookup
    Result = Struct.new(:hits_by_key, :miss_messages, :hydrated_raw_items, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(subject:, context_fingerprint:, prompt_version:, model_id:, messages:)
      @subject = subject
      @context_fingerprint = context_fingerprint
      @prompt_version = prompt_version
      @model_id = model_id
      @messages = Array(messages)
    end

    def call
      identifiable = []
      always_miss = []

      @messages.each do |message|
        m = message.with_indifferent_access
        channel_id = m[:channel_id].to_s
        message_ts = m[:ts].to_s
        if channel_id.blank? || message_ts.blank?
          always_miss << message
          next
        end

        identifiable << [PossibleObservationSlackSearchBatch.message_key(m), message, channel_id, message_ts]
      end

      memos = load_memos(identifiable)
      hits_by_key = {}
      miss_messages = always_miss.dup
      hydrated = []

      identifiable.each do |key, message, _channel_id, _message_ts|
        memo = memos[key]
        if memo
          items = memo.raw_item_list
          hits_by_key[key] = items
          hydrated.concat(items)
        else
          miss_messages << message
        end
      end

      Result.new(
        hits_by_key: hits_by_key,
        miss_messages: miss_messages,
        hydrated_raw_items: hydrated
      )
    end

    private

    def load_memos(identifiable)
      return {} if identifiable.empty?

      channel_ids = identifiable.map { |(_, _, channel_id, _)| channel_id }.uniq
      message_tses = identifiable.map { |(_, _, _, message_ts)| message_ts }.uniq

      SlackOgoExtractionMemo.where(
        subject_company_teammate_id: @subject.id,
        context_fingerprint: @context_fingerprint,
        prompt_version: @prompt_version,
        model_id: @model_id,
        channel_id: channel_ids,
        message_ts: message_tses
      ).index_by(&:message_key)
    end
  end
end
