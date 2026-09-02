# frozen_string_literal: true

# Age bands move with the calendar even when no new check-ins or surveys land,
# so every persisted Expectation Alignment Score must be recalculated daily.
class DailyRefreshAssignmentExpectationAlignmentScoresJob < ApplicationJob
  queue_as :default

  def perform
    AssignmentExpectationAlignmentScore.find_each do |row|
      AssignmentExpectationAlignmentScoreRefreshJob.perform_later(row.assignment_id)
    end
  end
end
