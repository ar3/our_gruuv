# frozen_string_literal: true

class AddDiscoverySearchIdsAndMemoStatsToSlackPogo < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_possible_observations, :discovery_search_ids, :jsonb, null: false, default: []
    add_index :slack_possible_observations, :discovery_search_ids, using: :gin

    add_column :possible_observation_slack_searches, :memo_hit_count, :integer, null: false, default: 0
    add_column :possible_observation_slack_searches, :memo_miss_count, :integer, null: false, default: 0
  end
end
