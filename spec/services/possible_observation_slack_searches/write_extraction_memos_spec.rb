# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::WriteExtractionMemos do
  let(:organization) { create(:organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }
  let(:fingerprint) { Digest::SHA256.hexdigest("ctx") }
  let(:prompt_version) { Llm::SlackMomentsExtractor::PROMPT_VERSION }
  let(:model_id) { "model-a" }
  let(:message) do
    {
      "channel_id" => "C9",
      "ts" => "999.1",
      "text" => "Great work on the launch this week everyone",
      "user" => "U9"
    }
  end

  it "writes a negative memo when no raw items match the message" do
    expect do
      described_class.call(
        subject: subject_tm,
        context_fingerprint: fingerprint,
        prompt_version: prompt_version,
        model_id: model_id,
        messages: [message],
        raw_items: []
      )
    end.to change(SlackOgoExtractionMemo, :count).by(1)

    memo = SlackOgoExtractionMemo.last
    expect(memo.channel_id).to eq("C9")
    expect(memo.message_ts).to eq("999.1")
    expect(memo.raw_items).to eq([])
  end

  it "attributes items by channel_id and ts" do
    raw = {
      "quote" => "Great work on the launch",
      "channel_id" => "C9",
      "ts" => "999.1",
      "confidence" => 0.9
    }

    described_class.call(
      subject: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      messages: [message],
      raw_items: [raw]
    )

    memo = SlackOgoExtractionMemo.last
    expect(memo.raw_items.size).to eq(1)
    expect(memo.raw_items.first["quote"]).to eq("Great work on the launch")
  end

  it "upserts on the uniqueness key" do
    described_class.call(
      subject: subject_tm,
      context_fingerprint: fingerprint,
      prompt_version: prompt_version,
      model_id: model_id,
      messages: [message],
      raw_items: []
    )

    expect do
      described_class.call(
        subject: subject_tm,
        context_fingerprint: fingerprint,
        prompt_version: prompt_version,
        model_id: model_id,
        messages: [message],
        raw_items: [{ "quote" => "updated", "channel_id" => "C9", "ts" => "999.1" }]
      )
    end.not_to change(SlackOgoExtractionMemo, :count)

    expect(SlackOgoExtractionMemo.last.raw_items.first["quote"]).to eq("updated")
  end
end
