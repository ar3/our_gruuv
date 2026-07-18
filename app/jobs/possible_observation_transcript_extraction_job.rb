# frozen_string_literal: true

class PossibleObservationTranscriptExtractionJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_transcript_id)
    transcript = PossibleObservationTranscript.find_by(id: possible_observation_transcript_id)
    return if transcript.nil?

    transcript.mark_processing!

    unless transcript.transcript_file.attached?
      transcript.mark_failed!('No transcript file attached.')
      return
    end

    plaintext = Transcripts::PlaintextFromBlobService.call(blob: transcript.transcript_file.blob)
    chunks = Transcripts::ChunkPlaintextService.call(plaintext)

    raw_by_chunk = []
    chunk_errors = []

    chunks.each do |chunk|
      transcript.heartbeat_processing!
      result = Llm::TranscriptMomentsExtractor.call(
        chunk_text: chunk,
        organization_id: transcript.organization_id,
        parent: transcript
      )
      raw_by_chunk << (result['items'] || [])
      chunk_errors << result['error'] if result['error'].present?
    end

    items = PossibleObservationTranscripts::MergeAndResolveExtractionsService.call(
      organization: transcript.organization,
      raw_items_by_chunk: raw_by_chunk
    )

    explanation =
      if items.empty?
        chunk_errors.compact.first.presence ||
          'No kudos or constructive feedback moments were found in this transcript.'
      end

    transcript.mark_completed!(items: items, extraction_note: explanation)
  rescue StandardError => e
    transcript&.mark_failed!(e.message)
    Rails.logger.error("PossibleObservationTranscriptExtractionJob #{possible_observation_transcript_id}: #{e.class} #{e.message}")
  end
end
