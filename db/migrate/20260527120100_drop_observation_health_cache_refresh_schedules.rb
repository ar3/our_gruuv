# frozen_string_literal: true

class DropObservationHealthCacheRefreshSchedules < ActiveRecord::Migration[8.0]
  def change
    drop_table :observation_health_cache_refresh_schedules, if_exists: true
  end
end
