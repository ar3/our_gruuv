# frozen_string_literal: true

class AddSourceMetadataToPossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_consults, :source_metadata, :jsonb, null: false, default: {}
  end
end
