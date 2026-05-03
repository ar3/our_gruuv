# frozen_string_literal: true

module Maap
  # Plain-text excerpt for 1:1 Hub Evolve card (no markdown rendering).
  module TeammateGrowthHubSummary
    module_function

    def excerpt_for_hub(run)
      return nil unless run&.status == 'completed' && run.output_text.present?

      parsed = ClaritySignalParser.call(run.output_text)
      text = parsed.body.to_s
      text = text.gsub(/\[(.*?)\]\([^)]+\)/m, '\1')
      text = text.gsub(/[#*_`>|]/, ' ')
      text.gsub(/\s+/, ' ').strip.truncate(280)
    end
  end
end
