# frozen_string_literal: true

class PossibleObservationSlackSearchExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_slack_search_id)
    search = PossibleObservationSlackSearch.find_by(id: possible_observation_slack_search_id)
    return if search.nil?
    return unless search.search_status == "completed"

    search.mark_extraction_processing!
    consultation = nil

    messages = search.raw_messages
    if messages.empty?
      consultation = OgConsultations::StartOgoSearch.call(
        subject: search,
        kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
        organization_id: search.organization_id,
        triggered_by_teammate_id: search.creator_company_teammate_id,
        units_total: 0,
        extraction_version: PossibleObservationSlackSearch::EXTRACTIONS_VERSION,
        model_id: Llm::SlackMomentsExtractor.model_id,
        prompt_version: Llm::SlackMomentsExtractor::PROMPT_VERSION
      )
      search.mark_extraction_completed!(
        items: [],
        extraction_note: "No Slack messages were available to extract from."
      )
      complete_consultation!(consultation, items_count: 0)
      return
    end

    chunks = PossibleObservationSlackSearches::ChunkMessagesService.call(messages)
    subject_name = search.subject_company_teammate.person.casual_name
    context_pack = PossibleObservationSlackSearches::SubjectContextPack.call(
      teammate: search.subject_company_teammate,
      organization: search.organization
    )

    consultation = OgConsultations::StartOgoSearch.call(
      subject: search,
      kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
      organization_id: search.organization_id,
      triggered_by_teammate_id: search.creator_company_teammate_id,
      units_total: chunks.size,
      extraction_version: PossibleObservationSlackSearch::EXTRACTIONS_VERSION,
      model_id: Llm::SlackMomentsExtractor.model_id,
      prompt_version: Llm::SlackMomentsExtractor::PROMPT_VERSION
    )

    raw_by_chunk = []
    chunk_errors = []

    chunks.each do |chunk_text|
      search.heartbeat_extraction_processing!
      result = Llm::SlackMomentsExtractor.call(
        chunk_text: chunk_text,
        subject_name: subject_name,
        context_text: context_pack.prompt_text,
        context_catalog: context_pack.catalog,
        organization_id: search.organization_id,
        parent: consultation,
        triggered_by_teammate_id: search.creator_company_teammate_id
      )
      raw_by_chunk << (result["items"] || [])
      chunk_errors << result["error"] if result["error"].present?
      consultation.increment_units_completed!
    end

    items = PossibleObservationSlackSearches::MergeAndResolveExtractionsService.call(
      search: search,
      raw_items_by_chunk: raw_by_chunk,
      context_catalog: context_pack.catalog,
      llm_parent: consultation
    )

    explanation =
      if items.empty?
        chunk_errors.compact.first.presence ||
          "No noteworthy OGO moments were found in these Slack messages."
      end

    search.mark_extraction_completed!(items: items, extraction_note: explanation)
    complete_consultation!(consultation, items_count: items.size)
  rescue StandardError => e
    fail_consultation!(consultation, e.message)
    search&.mark_extraction_failed!(e.message)
    Rails.logger.error(
      "PossibleObservationSlackSearchExtractionJob #{possible_observation_slack_search_id}: #{e.class} #{e.message}"
    )
  end

  private

  def complete_consultation!(consultation, items_count:)
    return if consultation.nil?

    result = consultation.result
    result.update!(items_count: items_count) if result.is_a?(OgoSearchResult)
    consultation.update!(
      status: "completed",
      completed_at: Time.current,
      error_message: nil
    )
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
