# frozen_string_literal: true

# Age bands move with the calendar even when no new Values check-ins land,
# so every persisted Values Expectation Alignment Score must be recalculated daily.
class DailyRefreshAspirationExpectationAlignmentScoresJob < ApplicationJob
  queue_as :default

  def perform
    AspirationExpectationAlignmentScore.find_each do |row|
      AspirationExpectationAlignmentScoreRefreshJob.perform_later(row.aspiration_id)
    end
  end
end
