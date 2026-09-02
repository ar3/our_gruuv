# frozen_string_literal: true

class AssignmentExpectationAlignmentScoreRefreshJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(assignment_id) { "expectation_alignment_score_#{assignment_id}" }

  def perform(assignment_id)
    assignment = Assignment.find_by(id: assignment_id)
    return unless assignment

    AssignmentSurveys::ExpectationAlignmentScore.recalculate!(assignment: assignment)
  end
end
