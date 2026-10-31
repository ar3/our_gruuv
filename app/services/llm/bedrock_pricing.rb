# frozen_string_literal: true

module Llm
  # On-demand Bedrock rates (USD per 1M tokens). Keep in sync with AWS pricing pages.
  # Matching is by substring against model_id (regional profile ids included).
  module BedrockPricing
    Rate = Data.define(:input_per_mtok, :output_per_mtok, :cache_read_per_mtok, :cache_write_per_mtok)

    # Rates as dollars per million tokens.
    RATES = {
      /nova-2-lite/i => Rate.new(0.30, 2.50, 0.03, 0.375),
      /nova-lite/i => Rate.new(0.06, 0.24, 0.015, 0.06),
      /nova-micro/i => Rate.new(0.035, 0.14, 0.00875, 0.035),
      /haiku-4-5/i => Rate.new(1.0, 5.0, 0.10, 1.25),
      /haiku/i => Rate.new(0.80, 4.0, 0.08, 1.0),
      /sonnet-4/i => Rate.new(3.0, 15.0, 0.30, 3.75),
      /sonnet/i => Rate.new(3.0, 15.0, 0.30, 3.75),
      /opus/i => Rate.new(5.0, 25.0, 0.50, 6.25)
    }.freeze

    DEFAULT_RATE = Rate.new(3.0, 15.0, 0.30, 3.75)

    module_function

    def rate_for(model_id)
      id = model_id.to_s
      RATES.each do |pattern, rate|
        return rate if id.match?(pattern)
      end
      DEFAULT_RATE
    end
  end
end
