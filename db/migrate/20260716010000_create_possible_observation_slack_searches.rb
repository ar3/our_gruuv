# frozen_string_literal: true

class CreatePossibleObservationSlackSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :possible_observation_slack_searches do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations }
      t.references :creator_company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :subject_company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :display_name, null: false
      t.integer :window_days, null: false, default: 90
      t.string :query, null: false, default: ""
      t.jsonb :raw_results, null: false, default: {}
      t.string :search_status, null: false, default: "pending"
      t.text :search_error
      t.jsonb :extractions, null: false, default: {}
      t.string :extraction_status, null: false, default: "pending"
      t.text :extraction_error

      t.timestamps
    end

    add_index :possible_observation_slack_searches, :search_status
    add_index :possible_observation_slack_searches, :extraction_status
    add_index :possible_observation_slack_searches,
              [:subject_company_teammate_id, :created_at],
              name: "index_poss_obs_slack_searches_on_subject_and_created"
  end
end
