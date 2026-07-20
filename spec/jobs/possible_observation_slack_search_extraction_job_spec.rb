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
      messages_count: 0
    )
    record.raw_results_file.attach(
      io: StringIO.new(JSON.generate({ 'version' => 1, 'messages' => [] })),
      filename: 'empty.json',
      content_type: 'application/json'
    )
    record
  end
  let!(:batch) do
    create(
      :possible_observation_slack_search_batch,
      possible_observation_slack_search: search,
      position: 1,
      message_keys: [],
      messages_count: 0,
      extraction_status: 'pending'
    )
  end

  it 'creates a billable ogo_search_slack consultation on the batch when there are no messages' do
    expect do
      described_class.perform_now(batch.id)
    end.to change(OgConsultation, :count).by(1)

    consultation = OgConsultation.order(:id).last
    expect(consultation.kind).to eq(OgConsultation::KIND_OGO_SEARCH_SLACK)
    expect(consultation.subject).to eq(batch)
    expect(consultation).to be_billable
    expect(consultation.status).to eq('completed')
    expect(consultation.model_id).to eq(Llm::SlackMomentsExtractor.model_id)
    expect(consultation.prompt_version).to eq(Llm::SlackMomentsExtractor::PROMPT_VERSION)
    expect(consultation.units_total).to eq(0)
    expect(consultation.result).to be_a(OgoSearchResult)
    expect(consultation.result.items_count).to eq(0)
    expect(batch.reload.extraction_status).to eq('completed')
  end

  it 'defaults to the Haiku model id' do
    expect(Llm::SlackMomentsExtractor.model_id).to include('claude-haiku-4-5')
    expect(Llm::SlackMomentsExtractor.stronger_model_id).to include('claude-sonnet-4-5')
  end

  it 'records the stronger model when requested' do
    described_class.perform_now(batch.id, model_id: Llm::SlackMomentsExtractor.stronger_model_id)

    consultation = OgConsultation.order(:id).last
    expect(consultation.subject).to eq(batch)
    expect(consultation.model_id).to eq(Llm::SlackMomentsExtractor.stronger_model_id)
    expect(batch.reload.extraction_status).to eq('completed')
  end

  describe 'extraction memos' do
    let!(:search) do
      record = create(
        :possible_observation_slack_search,
        organization: organization,
        creator_company_teammate: creator,
        subject_company_teammate: subject_teammate,
        search_status: 'completed',
        messages_count: 1,
        filtered_messages_count: 1
      )
      message = {
        'channel_id' => 'C123',
        'channel_name' => 'general',
        'user' => 'UOBS',
        'username' => 'alex',
        'ts' => '1710000000.000100',
        'text' => 'Pat did a great job on the launch and crushed the timeline completely.',
        'permalink' => 'https://example.slack.com/archives/C123/p1710000000000100'
      }
      record.raw_results_file.attach(
        io: StringIO.new(JSON.generate('version' => 1, 'messages' => [message])),
        filename: 'slack.json',
        content_type: 'application/json'
      )
      record
    end
    let!(:batch) do
      create(
        :possible_observation_slack_search_batch,
        possible_observation_slack_search: search,
        position: 1,
        message_keys: ['C123|1710000000.000100'],
        messages_count: 1,
        extraction_status: 'pending',
        oldest_ts: '1710000000.000100',
        newest_ts: '1710000000.000100'
      )
    end

    let(:raw_item) do
      {
        'kind' => 'kudos',
        'confidence' => 0.9,
        'target_is_subject' => true,
        'summary' => "#{subject_teammate.person.casual_name} crushed it",
        'short_quote' => "#{subject_teammate.person.casual_name} did a great job",
        'full_quote' => "#{subject_teammate.person.casual_name} did a great job on the launch and crushed the timeline completely.",
        'quote' => "#{subject_teammate.person.casual_name} crushed it",
        'speaker_label' => creator.person.casual_name,
        'recipient_label' => subject_teammate.person.casual_name,
        'channel_id' => 'C123',
        'ts' => '1710000000.000100',
        'permalink' => 'https://example.slack.com/archives/C123/p1710000000000100',
        'slack_user_id' => 'UOBS'
      }
    end
    before do
      create(:teammate_identity, :slack, teammate: creator, uid: 'UOBS')
      allow(Llm::SlackMomentsExtractor).to receive(:call).and_return('items' => [raw_item])
    end

    it 'writes a memo on first extraction and skips the LLM on a later run with the same inputs' do
      expect do
        described_class.perform_now(batch.id)
      end.to change(SlackOgoExtractionMemo, :count).by(1)
         .and change(OgConsultation, :count).by(1)

      expect(Llm::SlackMomentsExtractor).to have_received(:call).once
      first = OgConsultation.order(:id).last
      expect(first.units_total).to eq(1)
      expect(batch.reload.extraction_status).to eq('completed')
      expect(batch.extraction_items.size).to eq(1)

      batch.update!(extraction_status: 'pending', extractions: {}, extraction_error: nil)

      expect do
        described_class.perform_now(batch.id)
      end.to change(OgConsultation, :count).by(1)
         .and change(SlackOgoExtractionMemo, :count).by(0)

      expect(Llm::SlackMomentsExtractor).to have_received(:call).once
      second = OgConsultation.order(:id).last
      expect(second.units_total).to eq(0)
      expect(batch.reload.extraction_items.size).to eq(1)
      expect(batch.extraction_items.first[:channel_id]).to eq('C123')
    end

    it 'skips the LLM for negative memos and yields no candidates' do
      context_pack = PossibleObservationSlackSearches::SubjectContextPack.call(
        teammate: subject_teammate,
        organization: organization
      )
      create(
        :slack_ogo_extraction_memo,
        subject_company_teammate: subject_teammate,
        context_fingerprint: PossibleObservationSlackSearches::ContextFingerprint.compute(context_pack.prompt_text),
        prompt_version: Llm::SlackMomentsExtractor::PROMPT_VERSION,
        model_id: Llm::SlackMomentsExtractor.model_id,
        channel_id: 'C123',
        message_ts: '1710000000.000100',
        raw_items: []
      )

      described_class.perform_now(batch.id)

      expect(Llm::SlackMomentsExtractor).not_to have_received(:call)
      expect(batch.reload.extraction_items).to be_empty
      expect(OgConsultation.order(:id).last.units_total).to eq(0)
    end
  end
end
