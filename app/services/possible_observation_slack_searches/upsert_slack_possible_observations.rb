# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Forward-only: after a batch extract completes, upsert durable shared pOGO rows.
  # Unique on (subject, channel_id, message_ts). Re-finds append the searcher as a discoverer.
  class UpsertSlackPossibleObservations
    def self.call(search:, batch:, items:)
      new(search: search, batch: batch, items: items).call
    end

    def initialize(search:, batch:, items:)
      @search = search
      @batch = batch
      @items = Array(items)
      @messages_by_key = index_messages(search.raw_messages)
    end

    def call
      created_or_updated = 0

      @items.each do |item|
        next unless upsert_item!(item.stringify_keys)

        created_or_updated += 1
      end

      created_or_updated
    end

    private

    def upsert_item!(item)
      channel_id = item["channel_id"].to_s
      message_ts = item["ts"].to_s
      return false if channel_id.blank? || message_ts.blank?

      subject = @search.subject_company_teammate
      return false if subject.nil?

      source = @messages_by_key["#{channel_id}|#{message_ts}"] || {}
      visibility = ChannelVisibility.classify(source.merge(item.slice("channel_is_private", "channel_is_mpim", "match_type", "channel_id")))
      discoverer_id = @search.creator_company_teammate_id
      payload = build_payload(item, source)

      record = SlackPossibleObservation.find_or_initialize_by(
        subject_company_teammate_id: subject.id,
        channel_id: channel_id,
        message_ts: message_ts
      )

      if record.new_record?
        record.organization = @search.organization
        record.visibility = visibility
        record.discoverer_company_teammate_ids = [discoverer_id].compact
        record.discovery_search_ids = [@search.id]
        record.payload = payload
        record.possible_observation_slack_search = @search
        record.possible_observation_slack_search_batch = @batch
        record.extraction_item_id = item["id"].to_s.presence
        record.save!
      else
        record.update!(merge_existing_attrs(record, discoverer_id, visibility, payload))
      end

      true
    rescue ActiveRecord::RecordNotUnique
      # Race with another extract: re-find and append discoverer + search.
      record = SlackPossibleObservation.find_by!(
        subject_company_teammate_id: subject.id,
        channel_id: channel_id,
        message_ts: message_ts
      )
      record.update!(merge_existing_attrs(record, discoverer_id, visibility, payload))
      true
    end

    def merge_existing_attrs(record, discoverer_id, visibility, payload)
      ids = record.discoverer_ids
      ids << discoverer_id if discoverer_id.present? && !ids.include?(discoverer_id)
      search_ids = record.discovery_search_id_list
      search_ids << @search.id unless search_ids.include?(@search.id)

      attrs = {
        discoverer_company_teammate_ids: ids,
        discovery_search_ids: search_ids
      }
      if record.private_or_dm? && visibility == SlackPossibleObservation::VISIBILITY_PUBLIC
        attrs[:visibility] = visibility
      end
      attrs[:payload] = payload if record.payload_hash.blank?
      attrs[:possible_observation_slack_search_id] = record.possible_observation_slack_search_id || @search.id
      attrs[:possible_observation_slack_search_batch_id] =
        record.possible_observation_slack_search_batch_id || @batch.id
      attrs
    end

    def build_payload(item, source)
      {
        "quote" => item["quote"].to_s,
        "short_quote" => item["short_quote"].to_s,
        "full_quote" => item["full_quote"].to_s,
        "summary" => item["summary"].to_s,
        "confidence" => item["confidence"],
        "kind" => item["kind"].to_s,
        "permalink" => item["permalink"].presence || source[:permalink].to_s,
        "speaker_label" => item["speaker_label"].to_s,
        "channel_name" => source[:channel_name].to_s,
        "slack_user_id" => item["slack_user_id"].to_s,
        "responder_company_teammate_id" => item["responder_company_teammate_id"],
        "suggested_rateable_type" => item["suggested_rateable_type"],
        "suggested_rateable_id" => item["suggested_rateable_id"],
        "suggested_rateable_name" => item["suggested_rateable_name"],
        "suggested_rating" => item["suggested_rating"]
      }
    end

    def index_messages(messages)
      Array(messages).each_with_object({}) do |message, hash|
        msg = message.with_indifferent_access
        key = PossibleObservationSlackSearchBatch.message_key(msg)
        next if key.blank?

        hash[key] = msg
      end
    end
  end
end
