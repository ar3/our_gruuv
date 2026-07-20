# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Upserts per-message memos after an LLM pass (including negative/empty results).
  class WriteExtractionMemos
    def self.call(...)
      new(...).call
    end

    def initialize(subject:, context_fingerprint:, prompt_version:, model_id:, messages:, raw_items:)
      @subject = subject
      @context_fingerprint = context_fingerprint
      @prompt_version = prompt_version
      @model_id = model_id
      @messages = Array(messages)
      @raw_items = Array(raw_items).map { |item| item.is_a?(Hash) ? item.stringify_keys : item }
    end

    def call
      by_message = attribute_items_to_messages
      by_message.each do |message, items|
        m = message.with_indifferent_access
        channel_id = m[:channel_id].to_s
        message_ts = m[:ts].to_s
        next if channel_id.blank? || message_ts.blank?

        upsert!(channel_id: channel_id, message_ts: message_ts, items: items)
      end
    end

    private

    def attribute_items_to_messages
      by_key = {}
      @messages.each do |message|
        key = PossibleObservationSlackSearchBatch.message_key(message)
        m = message.with_indifferent_access
        next if m[:channel_id].blank? || m[:ts].blank?

        by_key[key] = { message: message, items: [] }
      end

      @raw_items.each do |item|
        key = item_message_key(item)
        if key.present? && by_key.key?(key)
          by_key[key][:items] << item
          next
        end

        match = find_message_by_quote(item)
        next unless match

        match_key = PossibleObservationSlackSearchBatch.message_key(match)
        by_key[match_key][:items] << item if by_key.key?(match_key)
      end

      by_key.values.to_h { |entry| [entry[:message], entry[:items]] }
    end

    def item_message_key(item)
      channel_id = item["channel_id"].to_s
      ts = item["ts"].to_s
      return nil if channel_id.blank? || ts.blank?

      PossibleObservationSlackSearchBatch.message_key("channel_id" => channel_id, "ts" => ts)
    end

    def find_message_by_quote(item)
      quote = (item["full_quote"].presence || item["short_quote"].presence || item["quote"]).to_s
      return nil if quote.blank?

      needle = quote.downcase.gsub(/\s+/, " ").strip[0, 80]
      @messages.find do |message|
        message.with_indifferent_access[:text].to_s.downcase.gsub(/\s+/, " ").include?(needle)
      end
    end

    def upsert!(channel_id:, message_ts:, items:)
      memo = SlackOgoExtractionMemo.find_or_initialize_by(
        subject_company_teammate_id: @subject.id,
        context_fingerprint: @context_fingerprint,
        prompt_version: @prompt_version,
        model_id: @model_id,
        channel_id: channel_id,
        message_ts: message_ts
      )
      memo.raw_items = items
      memo.save!
    rescue ActiveRecord::RecordNotUnique
      SlackOgoExtractionMemo.find_by!(
        subject_company_teammate_id: @subject.id,
        context_fingerprint: @context_fingerprint,
        prompt_version: @prompt_version,
        model_id: @model_id,
        channel_id: channel_id,
        message_ts: message_ts
      ).update!(raw_items: items)
    end
  end
end
