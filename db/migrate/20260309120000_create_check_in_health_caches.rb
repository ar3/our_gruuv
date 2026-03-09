# frozen_string_literal: true

class CreateCheckInHealthCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :check_in_health_caches do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: { to_table: :organizations }
      t.datetime :refreshed_at
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :check_in_health_caches, [:teammate_id, :organization_id], unique: true,
              name: "index_check_in_health_caches_on_teammate_and_organization"

    create_table :check_in_health_cache_refresh_schedules do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }, index: { unique: true }
      t.datetime :refresh_at, null: false

      t.timestamps
    end

    add_index :check_in_health_cache_refresh_schedules, :refresh_at,
              name: "index_check_in_health_cache_refresh_schedules_on_refresh_at"
  end
end
