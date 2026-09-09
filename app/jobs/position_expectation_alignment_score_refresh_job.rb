# frozen_string_literal: true

class PositionExpectationAlignmentScoreRefreshJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(position_id) { "position_expectation_alignment_score_#{position_id}" }

  def perform(position_id)
    position = Position.find_by(id: position_id)
    return unless position

    Positions::ExpectationAlignmentScore.recalculate!(position: position)
  end
end
