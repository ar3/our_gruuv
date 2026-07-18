# frozen_string_literal: true

class AddAutoExtractAfterSearchToPossibleObservationSlackSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_slack_searches, :auto_extract_after_search, :boolean,
               null: false, default: false
  end
end
