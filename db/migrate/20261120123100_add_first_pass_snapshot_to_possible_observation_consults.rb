# frozen_string_literal: true

class AddFirstPassSnapshotToPossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_consults, :first_pass_snapshot, :jsonb, null: false, default: {}
  end
end
