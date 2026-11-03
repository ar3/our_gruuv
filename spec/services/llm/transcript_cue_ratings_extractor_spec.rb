# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::TranscriptCueRatingsExtractor do
  it "keeps only catalog-backed rateables with per-item confidence" do
    allow_any_instance_of(described_class).to receive(:bedrock_configured?).and_return(true)
    allow(Llm::Client).to receive(:call).and_return(
      instance_double(
        Llm::Client::Result,
        content: {
          kind: "kudos",
          summary: "Pat crushed the launch.",
          association_reason: "Maps to Delivery.",
          rating_reason: "Strong example.",
          rateables: [
            {
              rateable_type: "Ability",
              rateable_id: 11,
              rateable_name: "Delivery",
              suggested_rating: "agree",
              confidence: 0.91,
              association_reason: "Launch praise",
              rating_reason: "Exceeded expectations"
            },
            {
              rateable_type: "Ability",
              rateable_id: 999,
              suggested_rating: "agree",
              confidence: 0.8
            }
          ]
        }.to_json
      )
    )

    result = described_class.call(
      quote: "Shout out to Pat for the launch.",
      observee_name: "Pat",
      observer_name: "Alex",
      context_text: "ABILITIES:\n- [Ability id=11] Delivery",
      context_catalog: { "Ability" => { 11 => "Delivery" } }
    )

    expect(result["summary"]).to eq("Pat crushed the launch.")
    expect(result["rateables"].size).to eq(1)
    expect(result["rateables"].first["rateable_id"]).to eq(11)
    expect(result["rateables"].first["confidence"]).to eq(0.91)
  end
end
