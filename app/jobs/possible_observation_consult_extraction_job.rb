# frozen_string_literal: true

class PossibleObservationConsultExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_consult_id, model_id: nil)
    consult = PossibleObservationConsult.find_by(id: possible_observation_consult_id)
    return if consult.nil?
    return unless consult.people_confirmed?

    model_id = model_id.presence || Llm::MultiTeammateMomentsExtractor.model_id
    consult.mark_processing!
    consultation = nil

    plaintext = consult.plaintext
    if plaintext.blank?
      consult.mark_failed!("No transcript content to consult.")
      return
    end

    teammates = consult.confirmed_teammates.includes(:person).to_a
    if teammates.empty?
      consult.mark_failed!("No confirmed teammates.")
      return
    end

    chunks = Transcripts::ChunkPlaintextService.call(plaintext)
    chunks = ["(empty)"] if chunks.empty?
    units_total = chunks.size * teammates.size

    consultation = OgConsultations::StartOgoSearch.call(
      subject: consult,
      kind: OgConsultation::KIND_OGO_SEARCH_CONSULT,
      organization_id: consult.organization_id,
      triggered_by_teammate_id: consult.creator_company_teammate_id,
      units_total: units_total,
      extraction_version: PossibleObservationConsult::EXTRACTIONS_VERSION,
      model_id: model_id,
      prompt_version: Llm::MultiTeammateMomentsExtractor.prompt_version
    )

    chunk_errors = []
    merged_catalog = {
      "Assignment" => {},
      "Ability" => {},
      "Aspiration" => {},
      "Goal" => {}
    }
    all_items = []
    processed_teammate_ids = []

    # One person at a time across all chunks so the show page can reveal
    # finished teammates while others are still processing.
    teammates.each do |teammate|
      raw_by_chunk = []

      chunks.each do |chunk|
        consult.heartbeat_processing!
        pack = PossibleObservationSlackSearches::SubjectContextPack.call(
          teammate: teammate,
          organization: consult.organization
        )
        pack.catalog.each do |type, map|
          merged_catalog[type] ||= {}
          merged_catalog[type].merge!(map)
        end

        subject_name = teammate.person.casual_name.presence || teammate.person.display_name
        result = Llm::MultiTeammateMomentsExtractor.call_for_subject(
          chunk_text: chunk,
          subject_name: subject_name,
          context_text: pack.prompt_text,
          context_catalog: pack.catalog,
          organization_id: consult.organization_id,
          parent: consultation,
          triggered_by_teammate_id: consult.creator_company_teammate_id,
          model_id: model_id
        )
        items = Array(result["items"]).map do |item|
          item.stringify_keys.merge("subject_company_teammate_id" => teammate.id)
        end
        raw_by_chunk << items
        chunk_errors << result["error"] if result["error"].present?
        consultation.increment_units_completed!
      end

      person_items = PossibleObservationConsults::MergeAndResolveExtractionsService.call(
        organization: consult.organization,
        confirmed_teammates: teammates,
        raw_items_by_chunk: raw_by_chunk,
        context_catalog: merged_catalog
      )
      all_items.concat(person_items)
      processed_teammate_ids << teammate.id
      consult.persist_partial_extractions!(
        items: all_items,
        processed_teammate_ids: processed_teammate_ids
      )
    end

    note =
      if all_items.empty?
        chunk_errors.compact.first.presence ||
          "No OGO candidates were found for the confirmed teammates."
      end

    consult.mark_completed!(
      items: all_items,
      extraction_note: note,
      processed_teammate_ids: processed_teammate_ids
    )
    complete_consultation!(consultation, items_count: all_items.size)
  rescue StandardError => e
    fail_consultation!(consultation, e.message)
    consult&.mark_failed!(e.message)
    Rails.logger.error(
      "PossibleObservationConsultExtractionJob #{possible_observation_consult_id}: #{e.class} #{e.message}"
    )
  end

  private

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
