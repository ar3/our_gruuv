# frozen_string_literal: true

class AddAutoExtractModelIdToPossibleObservationSlackSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_slack_searches, :auto_extract_model_id, :string
  end
end
