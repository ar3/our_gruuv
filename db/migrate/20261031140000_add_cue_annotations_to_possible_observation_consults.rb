# frozen_string_literal: true

class AddCueAnnotationsToPossibleObservationConsults < ActiveRecord::Migration[8.0]
  def change
    add_column :possible_observation_consults, :cue_annotations, :jsonb, null: false, default: {}
  end
end
