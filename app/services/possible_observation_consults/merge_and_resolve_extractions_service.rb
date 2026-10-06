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
      observee = resolve_observee(raw["recipient_label"].to_s, subject: subject)
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
        "responder_company_teammate_id" => speaker[:company_teammate_id],
        "subject_company_teammate_id" => subject.id,
        "observer_unknown" => speaker[:unknown],
        "observee_unknown" => false,
        "observer_alternates" => Array(speaker[:alternates]),
        "observee_alternates" => Array(observee[:alternates]),
        "suggested_rateable_type" => rateable_type,
        "suggested_rateable_id" => rateable_id,
        "suggested_rateable_name" => rateable_type && rateable_id ? @context_catalog.dig(rateable_type, rateable_id) : nil,
        "suggested_rating" => raw["suggested_rating"],
        "association_reason" => raw["association_reason"].to_s,
        "rating_reason" => raw["rating_reason"].to_s,
        "suggested_goal_id" => raw["suggested_goal_id"],
        "include" => speaker[:company_teammate_id].present? && confidence >= INCLUDE_CONFIDENCE
      }
    end

    def resolve_speaker(label)
      Transcripts::TeammateResolverService.call(
        organization: @organization,
        label: label,
        teammates: roster_teammates
      )
    end

    def resolve_observee(label, subject:)
      resolution = Transcripts::TeammateResolverService.call(
        organization: @organization,
        label: label,
        teammates: roster_teammates
      )
      ranked_ids = ([resolution[:company_teammate_id]] + Array(resolution[:alternates]).map { |alt| alt["company_teammate_id"] }).compact.map(&:to_i)
      return { alternates: [] } unless ranked_ids.include?(subject.id)

      names = Array(resolution[:alternates]).index_by { |alt| alt["company_teammate_id"].to_i }
      alternates = ranked_ids.filter_map do |id|
        next if id == subject.id

        names[id] || begin
          teammate = roster_teammates.find { |tm| tm.id == id }
          next unless teammate

          { "company_teammate_id" => teammate.id, "name" => teammate.person.display_name.to_s }
        end
      end

      { alternates: alternates.first(3) }
    end

    def roster_teammates
      @roster_teammates ||= CompanyTeammate.employed.where(organization_id: @org_ids).includes(:person).to_a
    end
  end
end
