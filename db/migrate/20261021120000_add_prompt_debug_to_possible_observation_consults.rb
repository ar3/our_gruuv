# frozen_string_literal: true

class AddPromptDebugToPossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_consults, :prompt_debug, :boolean, null: false, default: false
    add_index :possible_observation_consults, :prompt_debug
  end
end
