# frozen_string_literal: true

class DropCheckInHealthCaches < ActiveRecord::Migration[8.0]
  def change
    drop_table :check_in_health_cache_refresh_schedules, if_exists: true
    drop_table :check_in_health_caches, if_exists: true
  end
end
