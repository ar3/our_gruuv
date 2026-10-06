# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::OgoCandidateDisplayQuote do
  it "orders summary, full quote, then why, with no short quote" do
    text = described_class.compose(
      summary: "Pat shipped early.",
      full_quote: "Pat shipped early and crushed the launch.",
      why_lines: ["OG is suggesting: Strong example of the Assignment, Own launch."]
    )

    expect(text).to start_with("Pat shipped early.")
    expect(text).to include("Full quote: Pat shipped early and crushed the launch.")
    expect(text).to include("Why:")
    expect(text).to include("OG is suggesting: Strong example of the Assignment, Own launch.")
    expect(text).not_to include("Short quote:")
    expect(text.index("Pat shipped early.")).to be < text.index("Full quote:")
    expect(text.index("Full quote:")).to be < text.index("Why:")
  end
end
