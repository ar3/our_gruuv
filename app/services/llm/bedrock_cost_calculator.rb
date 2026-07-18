# frozen_string_literal: true

module Llm
  # Converts token counts + model_id into integer microdollars (1 USD = 1_000_000 micros).
  module BedrockCostCalculator
    MICROS_PER_DOLLAR = 1_000_000
    TOKENS_PER_MILLION = 1_000_000

    module_function

    def cost_micros(model_id:, input_tokens: 0, output_tokens: 0, cached_tokens: 0, cache_creation_tokens: 0)
      rate = BedrockPricing.rate_for(model_id)
      micros_for(input_tokens, rate.input_per_mtok) +
        micros_for(output_tokens, rate.output_per_mtok) +
        micros_for(cached_tokens, rate.cache_read_per_mtok) +
        micros_for(cache_creation_tokens, rate.cache_write_per_mtok)
    end

    def micros_for(tokens, dollars_per_mtok)
      tokens = tokens.to_i
      return 0 if tokens <= 0

      ((tokens * dollars_per_mtok * MICROS_PER_DOLLAR) / TOKENS_PER_MILLION).round
    end
    private_class_method :micros_for
  end
end
