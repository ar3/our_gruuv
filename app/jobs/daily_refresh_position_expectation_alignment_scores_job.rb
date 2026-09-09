# frozen_string_literal: true

# Required assignment outcomes/abilities can change without touching the position
# row, so every unarchived position's structural EAS is recalculated daily.
class DailyRefreshPositionExpectationAlignmentScoresJob < ApplicationJob
  queue_as :default

  def perform
    Position.unarchived.find_each do |position|
      PositionExpectationAlignmentScoreRefreshJob.perform_later(position.id)
    end
  end
end
