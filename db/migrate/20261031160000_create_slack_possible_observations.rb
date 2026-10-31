# frozen_string_literal: true

class CreateSlackPossibleObservations < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_possible_observations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :subject_company_teammate, null: false, foreign_key: { to_table: :teammates },
                   index: { name: "idx_slack_possible_observations_on_subject_id" }
      t.string :channel_id, null: false
      t.string :message_ts, null: false
      t.string :visibility, null: false, default: "private_or_dm"
      t.jsonb :discoverer_company_teammate_ids, null: false, default: []
      t.bigint :possible_observation_slack_search_id
      t.bigint :possible_observation_slack_search_batch_id
      t.string :extraction_item_id
      t.jsonb :payload, null: false, default: {}
      t.datetime :dismissed_at
      t.bigint :dismissed_by_company_teammate_id

      t.timestamps
    end

    add_index :slack_possible_observations,
              %i[subject_company_teammate_id channel_id message_ts],
              unique: true,
              name: "idx_slack_possible_observations_uniq"
    add_index :slack_possible_observations, :visibility
    add_index :slack_possible_observations, :dismissed_at
    add_foreign_key :slack_possible_observations, :possible_observation_slack_searches
    add_foreign_key :slack_possible_observations, :possible_observation_slack_search_batches
    add_foreign_key :slack_possible_observations, :teammates, column: :dismissed_by_company_teammate_id
  end
end
