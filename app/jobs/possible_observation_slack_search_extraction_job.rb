# frozen_string_literal: true

class PossibleObservationSlackSearchExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_slack_search_batch_id, model_id: nil)
    batch = PossibleObservationSlackSearchBatch.find_by(id: possible_observation_slack_search_batch_id)
    return if batch.nil?

    search = batch.possible_observation_slack_search
    return unless search.search_status == "completed"

    model_id = model_id.presence || Llm::SlackMomentsExtractor.model_id
    prompt_version = Llm::SlackMomentsExtractor::PROMPT_VERSION
    batch.mark_extraction_processing!
    consultation = nil

    messages = batch.messages
    if messages.empty?
      consultation = OgConsultations::StartOgoSearch.call(
        subject: batch,
        kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
        organization_id: search.organization_id,
        triggered_by_teammate_id: search.creator_company_teammate_id,
        units_total: 0,
        extraction_version: PossibleObservationSlackSearchBatch::EXTRACTIONS_VERSION,
        model_id: model_id,
        prompt_version: prompt_version
      )
      batch.mark_extraction_completed!(
        items: [],
        extraction_note: "No Slack messages were available in this consultation to extract from.",
        model_id: model_id
      )
      complete_consultation!(consultation, items_count: 0)
      return
    end

    subject = search.subject_company_teammate
    subject_name = subject.person.casual_name
    context_pack = PossibleObservationSlackSearches::SubjectContextPack.call(
      teammate: subject,
      organization: search.organization
    )
    context_fingerprint = PossibleObservationSlackSearches::ContextFingerprint.compute(context_pack.prompt_text)

    memo_lookup = PossibleObservationSlackSearches::ExtractionMemoLookup.call(
      subject: subject,
      context_fingerprint: context_fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      messages: messages
    )

    miss_messages = memo_lookup.miss_messages
    chunks = miss_messages.empty? ? [] : PossibleObservationSlackSearches::ChunkMessagesService.call(miss_messages)

    consultation = OgConsultations::StartOgoSearch.call(
      subject: batch,
      kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
      organization_id: search.organization_id,
      triggered_by_teammate_id: search.creator_company_teammate_id,
      units_total: chunks.size,
      extraction_version: PossibleObservationSlackSearchBatch::EXTRACTIONS_VERSION,
      model_id: model_id,
      prompt_version: prompt_version
    )

    raw_by_chunk = []
    chunk_errors = []
    fresh_raw_items = []

    if memo_lookup.hydrated_raw_items.any?
      raw_by_chunk << memo_lookup.hydrated_raw_items
    end

    chunks.each do |chunk_text|
      batch.heartbeat_extraction_processing!
      result = Llm::SlackMomentsExtractor.call(
        chunk_text: chunk_text,
        subject_name: subject_name,
        context_text: context_pack.prompt_text,
        context_catalog: context_pack.catalog,
        organization_id: search.organization_id,
        parent: consultation,
        triggered_by_teammate_id: search.creator_company_teammate_id,
        model_id: model_id
      )
      items = result["items"] || []
      raw_by_chunk << items
      fresh_raw_items.concat(items)
      chunk_errors << result["error"] if result["error"].present?
      consultation.increment_units_completed!
    end

    if miss_messages.any?
      PossibleObservationSlackSearches::WriteExtractionMemos.call(
        subject: subject,
        context_fingerprint: context_fingerprint,
        prompt_version: prompt_version,
        model_id: model_id,
        messages: miss_messages,
        raw_items: fresh_raw_items
      )
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

    batch.mark_extraction_completed!(items: items, extraction_note: explanation, model_id: model_id)
    complete_consultation!(consultation, items_count: items.size)
  rescue StandardError => e
    fail_consultation!(consultation, e.message)
    batch&.mark_extraction_failed!(e.message)
    Rails.logger.error(
      "PossibleObservationSlackSearchExtractionJob #{possible_observation_slack_search_batch_id}: #{e.class} #{e.message}"
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
