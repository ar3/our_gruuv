# frozen_string_literal: true

class AddMessagesCountToPossibleObservationSlackSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_slack_searches, :messages_count, :integer, null: false, default: 0
  end
end
