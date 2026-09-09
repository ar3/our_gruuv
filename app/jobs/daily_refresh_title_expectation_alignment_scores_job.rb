# frozen_string_literal: true

class DailyRefreshTitleExpectationAlignmentScoresJob < ApplicationJob
  queue_as :default

  def perform
    Title.unarchived.find_each do |title|
      TitleExpectationAlignmentScoreRefreshJob.perform_later(title.id)
    end
  end
end
