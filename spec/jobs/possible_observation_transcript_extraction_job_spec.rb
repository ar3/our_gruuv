# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PossibleObservationTranscriptExtractionJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let!(:transcript) do
    create(
      :possible_observation_transcript,
      :with_file,
      organization: organization,
      creator_company_teammate: creator,
      extraction_status: 'pending'
    )
  end

  it 'creates a billable ogo_search_transcript consultation and parents chunk calls' do
    allow(Transcripts::ChunkPlaintextService).to receive(:call).and_return(%w[chunk-a chunk-b])
    allow(Llm::TranscriptMomentsExtractor).to receive(:call).and_return({ 'items' => [] })
    allow(PossibleObservationTranscripts::MergeAndResolveExtractionsService).to receive(:call).and_return([])

    expect do
      described_class.perform_now(transcript.id)
    end.to change(OgConsultation, :count).by(1)

    consultation = OgConsultation.order(:id).last
    expect(consultation.kind).to eq(OgConsultation::KIND_OGO_SEARCH_TRANSCRIPT)
    expect(consultation.units_total).to eq(2)
    expect(consultation.units_completed).to eq(2)
    expect(consultation.status).to eq('completed')
    expect(consultation.model_id).to eq(Llm::TranscriptMomentsExtractor.model_id)
    expect(consultation.prompt_version).to eq(Llm::TranscriptMomentsExtractor::PROMPT_VERSION)
    expect(Llm::TranscriptMomentsExtractor).to have_received(:call).twice do |kwargs|
      expect(kwargs[:parent]).to eq(consultation)
    end
    expect(transcript.reload.extraction_status).to eq('completed')
  end
end
