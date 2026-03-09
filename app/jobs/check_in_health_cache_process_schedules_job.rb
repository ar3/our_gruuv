# frozen_string_literal: true

class CheckInHealthCacheProcessSchedulesJob < ApplicationJob
  queue_as :default

  def perform
    teammate_ids = CheckInHealthCacheRefreshSchedule.due_teammate_ids
    return if teammate_ids.empty?

    teammate_ids.each do |teammate_id|
      CheckInHealthCacheRefreshJob.perform_later(teammate_id)
    end
    CheckInHealthCacheRefreshSchedule.remove_schedule_for(teammate_ids)
  end
end
