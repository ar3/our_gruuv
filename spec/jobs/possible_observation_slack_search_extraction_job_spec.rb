# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PossibleObservationSlackSearchExtractionJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let!(:search) do
    record = create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject_teammate,
      search_status: 'completed',
      extraction_status: 'pending',
      messages_count: 0
    )
    record.raw_results_file.attach(
      io: StringIO.new(JSON.generate({ 'version' => 1, 'messages' => [] })),
      filename: 'empty.json',
      content_type: 'application/json'
    )
    record
  end

  it 'creates a billable ogo_search_slack consultation even when there are no messages' do
    expect do
      described_class.perform_now(search.id)
    end.to change(OgConsultation, :count).by(1)

    consultation = OgConsultation.order(:id).last
    expect(consultation.kind).to eq(OgConsultation::KIND_OGO_SEARCH_SLACK)
    expect(consultation.subject).to eq(search)
    expect(consultation).to be_billable
    expect(consultation.status).to eq('completed')
    expect(consultation.model_id).to eq(Llm::SlackMomentsExtractor.model_id)
    expect(consultation.prompt_version).to eq(Llm::SlackMomentsExtractor::PROMPT_VERSION)
    expect(consultation.units_total).to eq(0)
    expect(consultation.result).to be_a(OgoSearchResult)
    expect(consultation.result.items_count).to eq(0)
    expect(search.reload.extraction_status).to eq('completed')
  end

  it 'defaults to the Haiku model id' do
    expect(Llm::SlackMomentsExtractor.model_id).to include('claude-haiku-4-5')
    expect(Llm::SlackMomentsExtractor.stronger_model_id).to include('claude-sonnet-4-5')
  end

  it 'skips short messages and records the stronger model when requested' do
    payload = {
      'version' => 1,
      'messages' => [
        { 'text' => 'ok', 'ts' => '1.0', 'channel_id' => 'C1', 'user' => 'U1' },
        { 'text' => 'x' * 39, 'ts' => '2.0', 'channel_id' => 'C1', 'user' => 'U1' }
      ]
    }
    search.raw_results_file.attach(
      io: StringIO.new(JSON.generate(payload)),
      filename: 'short.json',
      content_type: 'application/json'
    )

    described_class.perform_now(search.id, model_id: Llm::SlackMomentsExtractor.stronger_model_id)

    consultation = OgConsultation.order(:id).last
    expect(consultation.model_id).to eq(Llm::SlackMomentsExtractor.stronger_model_id)
    expect(search.reload.extraction_status).to eq('completed')
    expect(search.extraction_error).to include('minimum length')
  end
end
