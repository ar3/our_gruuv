# frozen_string_literal: true

# Synchronously refreshes each unarchived position's EAS under the title, then
# persists the Title Expectation Alignment Score (avoids async race conditions).
class TitleExpectationAlignmentScoreRefreshJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(title_id) { "title_expectation_alignment_score_#{title_id}" }

  def perform(title_id)
    title = Title.find_by(id: title_id)
    return unless title

    Titles::ExpectationAlignmentScore.recalculate!(title: title, refresh_positions: true)
  end
end
