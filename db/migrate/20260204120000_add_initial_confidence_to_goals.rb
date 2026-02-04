# frozen_string_literal: true

class AddInitialConfidenceToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :initial_confidence, :string, default: 'stretch', null: true
    add_index :goals, :initial_confidence
  end
end
