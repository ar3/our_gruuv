# frozen_string_literal: true

module PossibleObservationConsults
  class MergeAndResolveExtractionsService
    INCLUDE_CONFIDENCE = Llm::SlackMomentsExtractor::INCLUDE_CONFIDENCE_THRESHOLD

    def self.call(organization:, confirmed_teammates:, raw_items_by_chunk:, context_catalog: {})
      new(
        organization: organization,
        confirmed_teammates: confirmed_teammates,
        raw_items_by_chunk: raw_items_by_chunk,
        context_catalog: context_catalog
      ).call
    end

    def initialize(organization:, confirmed_teammates:, raw_items_by_chunk:, context_catalog:)
      @organization = organization
      @confirmed_by_id = Array(confirmed_teammates).index_by(&:id)
      @raw_items_by_chunk = raw_items_by_chunk
      @context_catalog = context_catalog || {}
      @org_ids = organization.self_and_descendants.map(&:id)
    end

    def call
      Array(@raw_items_by_chunk).flat_map { |chunk| Array(chunk) }.filter_map { |raw| build_item(raw) }
    end

    private

    def build_item(raw)
      raw = raw.stringify_keys
      subject_id = raw["subject_company_teammate_id"].to_i
      subject = @confirmed_by_id[subject_id]
      return nil unless subject

      speaker = resolve_speaker(raw["speaker_label"].to_s)
      confidence = raw["confidence"].to_f
      rateable_type = raw["suggested_rateable_type"].to_s.presence
      rateable_id = raw["suggested_rateable_id"].presence&.to_i
      if rateable_type.present? && rateable_id.present?
        rateable_id = nil unless @context_catalog.dig(rateable_type, rateable_id).present?
        rateable_type = nil if rateable_id.blank?
      end

      {
        "id" => SecureRandom.uuid,
        "kind" => %w[kudos feedback].include?(raw["kind"].to_s) ? raw["kind"].to_s : "feedback",
        "confidence" => confidence,
        "quote" => raw["quote"].presence || [raw["summary"], raw["full_quote"]].compact_blank.join("\n\n"),
        "summary" => raw["summary"].to_s,
        "short_quote" => raw["short_quote"].to_s,
        "full_quote" => raw["full_quote"].to_s,
        "speaker_label" => raw["speaker_label"].to_s,
        "recipient_label" => raw["recipient_label"].presence || subject.person.casual_name,
        "responder_company_teammate_id" => speaker&.id,
        "subject_company_teammate_id" => subject.id,
        "observer_unknown" => speaker.nil?,
        "observee_unknown" => false,
        "suggested_rateable_type" => rateable_type,
        "suggested_rateable_id" => rateable_id,
        "suggested_rateable_name" => rateable_type && rateable_id ? @context_catalog.dig(rateable_type, rateable_id) : nil,
        "suggested_rating" => raw["suggested_rating"],
        "association_reason" => raw["association_reason"].to_s,
        "rating_reason" => raw["rating_reason"].to_s,
        "suggested_goal_id" => raw["suggested_goal_id"],
        "include" => speaker.present? && confidence >= INCLUDE_CONFIDENCE
      }
    end

    def resolve_speaker(label)
      return nil if label.blank?

      needle = label.downcase.strip
      CompanyTeammate
        .where(organization_id: @org_ids)
        .includes(:person)
        .find { |tm| name_match?(tm.person, needle) }
    end

    def name_match?(person, needle)
      return false unless person

      [person.casual_name, person.display_name, person.first_name, person.preferred_name]
        .compact_blank
        .any? { |n| n.downcase.strip == needle || needle.include?(n.downcase.strip) }
    end
  end
end
