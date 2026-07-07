# frozen_string_literal: true

# Required (not just a safety net): statuses decay with the passage of time
# alone, e.g. an item crosses from Healthy to Warning as thresholds elapse with no
# event occurring, so every status must be recalculated daily.
class DailyRefreshEngagementHealthStatusesJob < ApplicationJob
  queue_as :default

  def perform
    CompanyTeammate.employed.find_each do |teammate|
      EngagementHealthRefreshJob.perform_later(teammate.id)
    end
  end
end
