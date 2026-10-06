# frozen_string_literal: true

module Llm
  # Shared candidate story block for Slack and transcript potential OGOs.
  module OgoCandidateDisplayQuote
    SEPARATOR = ["", "", "====================", "", ""].freeze

    def self.compose(summary:, full_quote:, why_lines:)
      why = Array(why_lines).map { |line| line.to_s.presence }.compact
      why = ["(none)"] if why.empty?

      [
        summary.to_s.presence || "(none)",
        *SEPARATOR,
        "Full quote: #{full_quote.to_s.presence || '(none)'}",
        *SEPARATOR,
        "Why:",
        *why
      ].join("\n")
    end

    def self.suggestion_why_lines(rating_label:, rateable_type_label:, rateable_name:, association_reason:, rating_reason:)
      [
        "OG is suggesting: #{rating_label} example of the #{rateable_type_label}, #{rateable_name}.",
        "OG thought it was an example of #{rateable_name} because #{association_reason}.",
        "OG thought it was a #{rating_label} example because #{rating_reason}."
      ]
    end
  end
end
