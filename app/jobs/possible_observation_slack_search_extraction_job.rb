# frozen_string_literal: true

class PossibleObservationSlackSearchExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_slack_search_id)
    search = PossibleObservationSlackSearch.find_by(id: possible_observation_slack_search_id)
    return if search.nil?
    return unless search.search_status == "completed"

    search.mark_extraction_processing!

    messages = search.raw_messages
    if messages.empty?
      search.mark_extraction_completed!(
        items: [],
        extraction_note: "No Slack messages were available to extract from."
      )
      return
    end

    chunks = PossibleObservationSlackSearches::ChunkMessagesService.call(messages)
    subject_name = search.subject_company_teammate.person.casual_name
    context_pack = PossibleObservationSlackSearches::SubjectContextPack.call(
      teammate: search.subject_company_teammate,
      organization: search.organization
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
        parent: search,
        triggered_by_teammate_id: search.subject_company_teammate_id
      )
      raw_by_chunk << (result["items"] || [])
      chunk_errors << result["error"] if result["error"].present?
    end

    items = PossibleObservationSlackSearches::MergeAndResolveExtractionsService.call(
      search: search,
      raw_items_by_chunk: raw_by_chunk,
      context_catalog: context_pack.catalog
    )

    explanation =
      if items.empty?
        chunk_errors.compact.first.presence ||
          "No noteworthy OGO moments were found in these Slack messages."
      end

    search.mark_extraction_completed!(items: items, extraction_note: explanation)
  rescue StandardError => e
    search&.mark_extraction_failed!(e.message)
    Rails.logger.error(
      "PossibleObservationSlackSearchExtractionJob #{possible_observation_slack_search_id}: #{e.class} #{e.message}"
    )
  end
end
