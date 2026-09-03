# frozen_string_literal: true

class AspirationExpectationAlignmentScoreRefreshJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(aspiration_id) { "aspiration_expectation_alignment_score_#{aspiration_id}" }

  def perform(aspiration_id)
    aspiration = Aspiration.find_by(id: aspiration_id)
    return unless aspiration

    Aspirations::ExpectationAlignmentScore.recalculate!(aspiration: aspiration)
  end
end
