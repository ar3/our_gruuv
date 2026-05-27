# frozen_string_literal: true

class CreateObservationHealthCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :observation_health_caches do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: { to_table: :organizations }
      t.datetime :refreshed_at
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :observation_health_caches, [:teammate_id, :organization_id], unique: true,
              name: "index_observation_health_caches_on_teammate_and_organization"
  end
end
