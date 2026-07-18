# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::BedrockCostCalculator do
  it 'computes microdollar cost for Haiku token usage' do
    cost = described_class.cost_micros(
      model_id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
      input_tokens: 1_000_000,
      output_tokens: 1_000_000
    )
    # $1 input + $5 output = $6 = 6_000_000 micros
    expect(cost).to eq(6_000_000)
  end

  it 'includes cache read tokens at cache rate' do
    cost = described_class.cost_micros(
      model_id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
      cached_tokens: 1_000_000
    )
    expect(cost).to eq(100_000) # $0.10
  end
end
