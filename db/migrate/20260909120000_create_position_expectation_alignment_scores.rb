# frozen_string_literal: true

class CreatePositionExpectationAlignmentScores < ActiveRecord::Migration[8.0]
  def change
    create_table :position_expectation_alignment_scores do |t|
      t.references :position, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.decimal :score, precision: 5, scale: 1
      t.jsonb :cells, null: false, default: []
      t.integer :required_assignments_count, null: false, default: 0
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :position_expectation_alignment_scores, :calculated_at
  end
end
