# frozen_string_literal: true

class CheckInHealthCacheRefreshSchedule < ApplicationRecord
  DEBOUNCE_SECONDS = 10

  belongs_to :teammate, class_name: 'CompanyTeammate'

  validates :refresh_at, presence: true

  # Upsert: set refresh_at to now + DEBOUNCE_SECONDS for the given teammate
  def self.schedule_refresh_for(teammate_id)
    refresh_at = Time.current + DEBOUNCE_SECONDS.seconds
    schedule = find_or_initialize_by(teammate_id: teammate_id)
    schedule.refresh_at = refresh_at
    schedule.save!
  end

  # Teammate IDs that are due for refresh (refresh_at <= now)
  def self.due_teammate_ids
    where('refresh_at <= ?', Time.current).pluck(:teammate_id)
  end

  def self.remove_schedule_for(teammate_ids)
    where(teammate_id: teammate_ids).delete_all
  end
end
