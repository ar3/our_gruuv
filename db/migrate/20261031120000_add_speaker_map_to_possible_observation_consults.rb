# frozen_string_literal: true

class AddSpeakerMapToPossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_consults, :speaker_map, :jsonb, null: false, default: {}
  end
end
