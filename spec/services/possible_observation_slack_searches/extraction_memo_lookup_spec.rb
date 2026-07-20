# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::ExtractionMemoLookup do
  let(:organization) { create(:organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }
  let(:fingerprint) { Digest::SHA256.hexdigest("test-context") }
  let(:prompt_version) { "1.20260718.0" }
  let(:model_id) { "test-model" }

  let(:message_a) do
    {
      "channel_id" => "C1",
      "ts" => "100.1",
      "text" => "a" * 50,
      "user" => "U1"
    }
  end
  let(:message_b) do
    {
      "channel_id" => "C2",
      "ts" => "200.2",
      "text" => "b" * 50,
      "user" => "U2"
    }
  end

  it "returns misses when no memos exist" do
    result = described_class.call(
      subject: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      messages: [message_a, message_b]
    )

    expect(result.miss_messages).to contain_exactly(message_a, message_b)
    expect(result.hydrated_raw_items).to be_empty
    expect(result.hits_by_key).to be_empty
  end

  it "hydrates hits and leaves other messages as misses" do
    create(
      :slack_ogo_extraction_memo,
      subject_company_teammate: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      channel_id: "C1",
      message_ts: "100.1",
      raw_items: [{ "quote" => "cached", "channel_id" => "C1", "ts" => "100.1" }]
    )

    result = described_class.call(
      subject: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      messages: [message_a, message_b]
    )

    expect(result.miss_messages).to eq([message_b])
    expect(result.hydrated_raw_items.size).to eq(1)
    expect(result.hydrated_raw_items.first["quote"]).to eq("cached")
    expect(result.hits_by_key["C1|100.1"]).to be_present
  end

  it "treats empty raw_items as a hit (negative cache)" do
    create(
      :slack_ogo_extraction_memo,
      subject_company_teammate: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      channel_id: "C1",
      message_ts: "100.1",
      raw_items: []
    )

    result = described_class.call(
      subject: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      messages: [message_a]
    )

    expect(result.miss_messages).to be_empty
    expect(result.hydrated_raw_items).to be_empty
    expect(result.hits_by_key).to have_key("C1|100.1")
  end
end
