# frozen_string_literal: true

class CreatePossibleObservationSlackSearchBatches < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_slack_searches, :filtered_messages_count, :integer, null: false, default: 0

    create_table :possible_observation_slack_search_batches do |t|
      t.references :possible_observation_slack_search, null: false, foreign_key: true,
                   index: { name: "idx_poss_obs_slack_search_batches_on_search_id" }
      t.integer :position, null: false
      t.jsonb :message_keys, null: false, default: []
      t.integer :messages_count, null: false, default: 0
      t.string :oldest_ts
      t.string :newest_ts
      t.jsonb :extractions, null: false, default: {}
      t.string :extraction_status, null: false, default: "ready"
      t.text :extraction_error

      t.timestamps
    end

    add_index :possible_observation_slack_search_batches,
              %i[possible_observation_slack_search_id position],
              unique: true,
              name: "idx_poss_obs_slack_search_batches_on_search_and_position"
    add_index :possible_observation_slack_search_batches, :extraction_status
  end
end
