# frozen_string_literal: true

# OG-admin only: recent LLM invocations grouped by purpose with Bedrock cost estimates.
class LlmInvocationsController < ApplicationController
  KNOWN_PURPOSES = %w[
    ability_clarity
    assignment_clarity
    position_clarity
    teammate_growth
    transcript_chunk
    slack_chunk
    teammate_resolve
    abilities_hr_enrich
    abilities_hr_match
  ].freeze

  PER_PURPOSE_LIMIT = 5

  def show
    authorize LlmInvocation, :show?

    purposes = (KNOWN_PURPOSES | LlmInvocation.distinct.pluck(:purpose)).sort
    @invocations_by_purpose = purposes.filter_map do |purpose|
      rows = LlmInvocation
             .where(purpose: purpose)
             .includes(:organization, :triggered_by_teammate)
             .order(created_at: :desc, id: :desc)
             .limit(PER_PURPOSE_LIMIT)
             .to_a
      next if rows.empty?

      costs = rows.map { |row| calculated_cost_micros(row) }
      {
        purpose: purpose,
        label: purpose.to_s.tr('_', ' ').titleize,
        invocations: rows,
        costs_micros: costs,
        anticipated_cost_micros: average_micros(costs)
      }
    end
  end

  private

  def calculated_cost_micros(invocation)
    Llm::BedrockCostCalculator.cost_micros(
      model_id: invocation.model_id,
      input_tokens: invocation.input_tokens,
      output_tokens: invocation.output_tokens,
      cached_tokens: invocation.cached_tokens,
      cache_creation_tokens: invocation.cache_creation_tokens
    )
  end

  def average_micros(costs)
    present = costs.compact
    return nil if present.empty?

    (present.sum.to_f / present.size).round
  end
end
