# frozen_string_literal: true

class DailyRefreshObservationHealthCachesJob < ApplicationJob
  queue_as :default

  def perform
    CompanyTeammate.employed.find_each do |teammate|
      ObservationHealthCacheRefreshJob.perform_later(teammate.id)
    end
  end
end
