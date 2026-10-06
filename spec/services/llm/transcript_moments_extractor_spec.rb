# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::TranscriptMomentsExtractor do
  def parse(json)
    described_class.new(chunk_text: "hello").send(:parse_items, json)
  end

  it "composes summary, full quote, then why" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "This is a story about when Pat shipped early.",
          "full_quote": "Pat shipped early and crushed the launch.",
          "speaker_label": "Alex",
          "recipient_label": "Pat",
          "association_reason": "It shows ownership of the launch.",
          "rating_reason": "Shipping early exceeded the expected timeline."
        }]
      }
    JSON

    quote = result["items"].first["quote"]
    expect(quote).to start_with("This is a story about when Pat shipped early.")
    expect(quote).to include("Full quote: Pat shipped early and crushed the launch.")
    expect(quote).to include("Why:")
    expect(quote).to include("It shows ownership of the launch.")
    expect(quote).not_to include("Short quote:")
  end
end
