# frozen_string_literal: true

class PossibleObservationTranscriptExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_transcript_id)
    transcript = PossibleObservationTranscript.find_by(id: possible_observation_transcript_id)
    return if transcript.nil?

    transcript.mark_processing!
    consultation = nil

    unless transcript.transcript_file.attached?
      transcript.mark_failed!('No transcript file attached.')
      return
    end

    plaintext = Transcripts::PlaintextFromBlobService.call(blob: transcript.transcript_file.blob)
    chunks = Transcripts::ChunkPlaintextService.call(plaintext)

    consultation = OgConsultations::StartOgoSearch.call(
      subject: transcript,
      kind: OgConsultation::KIND_OGO_SEARCH_TRANSCRIPT,
      organization_id: transcript.organization_id,
      triggered_by_teammate_id: transcript.creator_company_teammate_id,
      units_total: chunks.size,
      extraction_version: PossibleObservationTranscript::EXTRACTIONS_VERSION,
      model_id: Llm::TranscriptMomentsExtractor.model_id,
      prompt_version: Llm::TranscriptMomentsExtractor::PROMPT_VERSION
    )

    raw_by_chunk = []
    chunk_errors = []

    chunks.each do |chunk|
      transcript.heartbeat_processing!
      result = Llm::TranscriptMomentsExtractor.call(
        chunk_text: chunk,
        organization_id: transcript.organization_id,
        parent: consultation,
        triggered_by_teammate_id: transcript.creator_company_teammate_id
      )
      raw_by_chunk << (result['items'] || [])
      chunk_errors << result['error'] if result['error'].present?
      consultation.increment_units_completed!
    end

    items = PossibleObservationTranscripts::MergeAndResolveExtractionsService.call(
      organization: transcript.organization,
      raw_items_by_chunk: raw_by_chunk,
      llm_parent: consultation
    )

    explanation =
      if items.empty?
        chunk_errors.compact.first.presence ||
          'No kudos or constructive feedback moments were found in this transcript.'
      end

    transcript.mark_completed!(items: items, extraction_note: explanation)
    complete_consultation!(consultation, items_count: items.size)
  rescue StandardError => e
    fail_consultation!(consultation, e.message)
    transcript&.mark_failed!(e.message)
    Rails.logger.error("PossibleObservationTranscriptExtractionJob #{possible_observation_transcript_id}: #{e.class} #{e.message}")
  end

  private

  def complete_consultation!(consultation, items_count:)
    return if consultation.nil?

    result = consultation.result
    result.update!(items_count: items_count) if result.is_a?(OgoSearchResult)
    consultation.update!(
      status: 'completed',
      completed_at: Time.current,
      error_message: nil
    )
  end

  def fail_consultation!(consultation, message)
    return if consultation.nil?

    consultation.update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: message.to_s.truncate(10_000)
    )
  end
end
