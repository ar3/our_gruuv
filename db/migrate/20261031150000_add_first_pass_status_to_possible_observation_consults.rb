# frozen_string_literal: true

class AddFirstPassStatusToPossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_consults, :first_pass_status, :string, null: false, default: "ready"
    add_column :possible_observation_consults, :first_pass_error, :text
    add_index :possible_observation_consults, :first_pass_status
  end
end
