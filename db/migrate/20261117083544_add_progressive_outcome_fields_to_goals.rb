# frozen_string_literal: true

class AddProgressiveOutcomeFieldsToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :outcome_baseline, :decimal, precision: 12, scale: 4
    add_column :goals, :outcome_commit, :decimal, precision: 12, scale: 4
    add_column :goals, :outcome_stretch, :decimal, precision: 12, scale: 4
    add_column :goals, :outcome_transform, :decimal, precision: 12, scale: 4
    add_column :goals, :outcome_unit, :string
    add_column :goals, :progressive_current_aim, :string
    add_column :goals, :outcome_fields_manually_edited_at, :datetime
  end
end
