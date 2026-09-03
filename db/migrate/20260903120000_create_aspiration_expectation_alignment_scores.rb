# frozen_string_literal: true

class CreateAspirationExpectationAlignmentScores < ActiveRecord::Migration[8.0]
  def change
    create_table :aspiration_expectation_alignment_scores do |t|
      t.references :aspiration, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.decimal :score, precision: 5, scale: 1
      t.jsonb :cells, null: false, default: []
      t.integer :check_in_teammate_count, null: false, default: 0
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :aspiration_expectation_alignment_scores, :calculated_at
  end
end
