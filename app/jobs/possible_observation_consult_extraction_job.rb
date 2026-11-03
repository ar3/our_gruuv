# frozen_string_literal: true

class PossibleObservationConsultExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_consult_id, model_id: nil)
    consult = PossibleObservationConsult.find_by(id: possible_observation_consult_id)
    return if consult.nil?
    return unless consult.people_confirmed?

    model_id = model_id.presence || Llm::TranscriptCueRatingsExtractor.model_id
    consult.mark_processing!
    consultation = nil

    items = PossibleObservationConsults::SeedExtractionItemsFromWorthyCues.call(consult: consult)
    if items.empty?
      consult.mark_completed!(
        items: [],
        extraction_note: "No OGO-worthy cues were confirmed in Step 2.",
        processed_teammate_ids: Array(consult.confirmed_teammate_ids).map(&:to_i)
      )
      return
    end

    consultation = OgConsultations::StartOgoSearch.call(
      subject: consult,
      kind: OgConsultation::KIND_OGO_SEARCH_CONSULT,
      organization_id: consult.organization_id,
      triggered_by_teammate_id: consult.creator_company_teammate_id,
      units_total: items.size,
      extraction_version: PossibleObservationConsult::EXTRACTIONS_VERSION,
      model_id: model_id,
      prompt_version: Llm::TranscriptCueRatingsExtractor.prompt_version
    )

    teammates_by_id = CompanyTeammate.where(id: items.flat_map { |item|
      [item["responder_company_teammate_id"], item["subject_company_teammate_id"]]
    }.compact).includes(:person).index_by(&:id)

    rated_items = []
    rating_errors = []

    items.each do |item|
      consult.heartbeat_processing!
      subject = teammates_by_id[item["subject_company_teammate_id"].to_i]
      observer = teammates_by_id[item["responder_company_teammate_id"].to_i]

      if subject.nil?
        rated_items << item
        rating_errors << "Cue #{item['id']}: missing observee"
        consultation.increment_units_completed!
        consult.persist_partial_extractions!(
          items: rated_items,
          processed_teammate_ids: rated_subject_ids(rated_items)
        )
        next
      end

      pack = PossibleObservationSlackSearches::SubjectContextPack.call(
        teammate: subject,
        organization: consult.organization
      )
      result = Llm::TranscriptCueRatingsExtractor.call(
        quote: item["quote"],
        observee_name: subject.person.casual_name.presence || subject.person.display_name,
        observer_name: observer&.person&.casual_name.presence || observer&.person&.display_name,
        context_text: pack.prompt_text,
        context_catalog: pack.catalog,
        organization_id: consult.organization_id,
        parent: consultation,
        triggered_by_teammate_id: consult.creator_company_teammate_id,
        model_id: model_id
      )
      rating_errors << result["error"] if result["error"].present?
      rated_items << apply_ratings(item, result)
      consultation.increment_units_completed!
      consult.persist_partial_extractions!(
        items: rated_items,
        processed_teammate_ids: rated_subject_ids(rated_items)
      )
    end

    note =
      if rated_items.empty?
        rating_errors.compact.first.presence || "No OGO candidates were rated."
      end

    consult.mark_completed!(
      items: rated_items,
      extraction_note: note,
      processed_teammate_ids: rated_subject_ids(rated_items).presence ||
        Array(consult.confirmed_teammate_ids).map(&:to_i)
    )
    complete_consultation!(consultation, items_count: rated_items.size)
  rescue StandardError => e
    fail_consultation!(consultation, e.message)
    consult&.mark_failed!(e.message)
    Rails.logger.error(
      "PossibleObservationConsultExtractionJob #{possible_observation_consult_id}: #{e.class} #{e.message}"
    )
  end

  private

  def apply_ratings(item, result)
    rateables = Array(result["rateables"]).map(&:stringify_keys)
    primary = rateables.first || {}
    confidences = rateables.filter_map { |row| row["confidence"]&.to_f }
    item.merge(
      "kind" => result["kind"].presence || item["kind"],
      "summary" => result["summary"].to_s,
      "association_reason" => result["association_reason"].to_s,
      "rating_reason" => result["rating_reason"].to_s,
      "suggested_rateables" => rateables,
      "suggested_rateable_type" => primary["rateable_type"],
      "suggested_rateable_id" => primary["rateable_id"],
      "suggested_rateable_name" => primary["rateable_name"],
      "suggested_rating" => primary["suggested_rating"],
      "confidence" => confidences.max
    )
  end

  def rated_subject_ids(items)
    items.filter_map { |item| item["subject_company_teammate_id"].presence&.to_i }.uniq
  end

  def complete_consultation!(consultation, items_count:)
    return if consultation.nil?

    result = consultation.result
    result.update!(items_count: items_count) if result.is_a?(OgoSearchResult)
    consultation.update!(status: "completed", completed_at: Time.current, error_message: nil)
  end

  def fail_consultation!(consultation, message)
    return if consultation.nil?

    consultation.update!(
      status: "failed",
      completed_at: Time.current,
      error_message: message.to_s.truncate(10_000)
    )
  end
end
