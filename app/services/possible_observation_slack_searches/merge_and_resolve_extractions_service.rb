# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Merges chunk extractions, resolves speaker via Slack UID, defaults subject to search subject.
  class MergeAndResolveExtractionsService
    def self.call(search:, raw_items_by_chunk:, context_catalog: nil)
      new(search: search, raw_items_by_chunk: raw_items_by_chunk, context_catalog: context_catalog).call
    end

    def initialize(search:, raw_items_by_chunk:, context_catalog: nil)
      @search = search
      @organization = search.organization
      @raw_items_by_chunk = raw_items_by_chunk
      @default_subject = search.subject_company_teammate
      @context_catalog = context_catalog || {}
    end

    def call
      merged = []
      seen = Set.new
      teammates = CompanyTeammate.employed.where(organization: @organization).includes(:person).to_a
      resolution_cache = {}

      @raw_items_by_chunk.each do |items|
        Array(items).each do |raw|
          enriched = enrich_from_raw_messages(raw)
          key = dedupe_key(enriched)
          next if key.blank? || seen.include?(key)

          seen.add(key)
          merged << build_item(enriched, teammates: teammates, resolution_cache: resolution_cache)
        end
      end

      merged
    end

    private

    def enrich_from_raw_messages(raw)
      out = raw.stringify_keys
      return out if out["channel_id"].present? && out["ts"].present?

      match = find_source_message(out)
      return out unless match

      out["channel_id"] = match[:channel_id].to_s if out["channel_id"].blank?
      out["ts"] = match[:ts].to_s if out["ts"].blank?
      out["permalink"] = match[:permalink].to_s if out["permalink"].blank?
      out["slack_user_id"] = match[:user].to_s if out["slack_user_id"].blank?
      out["speaker_label"] = match[:username].to_s if out["speaker_label"].blank?
      out
    end

    def find_source_message(raw)
      quote = (raw["full_quote"].presence || raw["short_quote"].presence || raw["quote"]).to_s
      return nil if quote.blank?

      needle = quote.downcase.gsub(/\s+/, " ").strip[0, 80]
      @search.raw_messages.find do |message|
        message[:text].to_s.downcase.gsub(/\s+/, " ").include?(needle)
      end
    end

    def dedupe_key(raw)
      if raw["channel_id"].present? && raw["ts"].present?
        return "#{raw['channel_id']}|#{raw['ts']}"
      end

      q = (raw["full_quote"].presence || raw["short_quote"].presence || raw["quote"]).to_s
      q = q.downcase.gsub(/\s+/, " ").strip[0, 200]
      "#{raw['slack_user_id']}|#{q}"
    end

    def build_item(raw, teammates:, resolution_cache:)
      speaker = resolve_speaker(raw, teammates: teammates, resolution_cache: resolution_cache)
      subject_id = @default_subject&.id
      subject_unknown = subject_id.blank?
      suggestion = validated_suggestion(raw)

      {
        "id" => SecureRandom.uuid,
        "kind" => raw["kind"],
        "quote" => raw["quote"].to_s,
        "summary" => raw["summary"].to_s,
        "short_quote" => raw["short_quote"].to_s,
        "full_quote" => raw["full_quote"].to_s,
        "speaker_label" => raw["speaker_label"].to_s,
        "recipient_label" => raw["recipient_label"].presence || @default_subject&.person&.casual_name.to_s,
        "responder_company_teammate_id" => speaker[:company_teammate_id],
        "subject_company_teammate_id" => subject_id,
        "observer_unknown" => speaker[:unknown],
        "observee_unknown" => subject_unknown,
        "channel_id" => raw["channel_id"].to_s,
        "ts" => raw["ts"].to_s,
        "permalink" => raw["permalink"].to_s,
        "slack_user_id" => raw["slack_user_id"].to_s,
        "suggested_rateable_type" => suggestion[:rateable_type],
        "suggested_rateable_id" => suggestion[:rateable_id],
        "suggested_rating" => suggestion[:rating],
        "suggested_goal_id" => suggestion[:goal_id],
        "include" => !speaker[:unknown] && !subject_unknown
      }
    end

    def validated_suggestion(raw)
      type = raw["suggested_rateable_type"].to_s
      type = nil unless %w[Assignment Ability Aspiration].include?(type)
      id = raw["suggested_rateable_id"].to_i
      id = nil if id <= 0
      if type.present? && id.present? && @context_catalog.present?
        id = nil unless @context_catalog.dig(type, id).present?
      end
      type = nil if id.blank?

      rating = raw["suggested_rating"].to_s
      rating = nil unless %w[strongly_agree agree disagree strongly_disagree].include?(rating)

      goal_id = raw["suggested_goal_id"].to_i
      goal_id = nil if goal_id <= 0
      if goal_id.present? && @context_catalog.present?
        goal_id = nil unless @context_catalog.dig("Goal", goal_id).present?
      end

      { rateable_type: type, rateable_id: id, rating: rating, goal_id: goal_id }
    end

    def resolve_speaker(raw, teammates:, resolution_cache:)
      slack_user_id = raw["slack_user_id"].to_s.strip
      if slack_user_id.present?
        cache_key = "slack:#{slack_user_id}"
        return resolution_cache[cache_key] if resolution_cache.key?(cache_key)

        teammate = TeammateIdentity.find_teammate_by_slack_id(slack_user_id, @organization)
        resolution_cache[cache_key] =
          if teammate
            { company_teammate_id: teammate.id, unknown: false }
          else
            resolve_label(raw["speaker_label"], teammates: teammates, resolution_cache: resolution_cache)
          end
        return resolution_cache[cache_key]
      end

      resolve_label(raw["speaker_label"], teammates: teammates, resolution_cache: resolution_cache)
    end

    def resolve_label(label, teammates:, resolution_cache:)
      key = "label:#{label.to_s.strip.downcase}"
      resolution_cache[key] ||= Transcripts::TeammateResolverService.call(
        organization: @organization,
        label: label,
        teammates: teammates
      )
    end
  end
end
