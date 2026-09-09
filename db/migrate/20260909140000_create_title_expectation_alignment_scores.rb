# frozen_string_literal: true

class CreateTitleExpectationAlignmentScores < ActiveRecord::Migration[8.0]
  def change
    create_table :title_expectation_alignment_scores do |t|
      t.references :title, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.decimal :score, precision: 5, scale: 1
      t.jsonb :cells, null: false, default: []
      t.boolean :path_clarity, null: false, default: false
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :title_expectation_alignment_scores, :calculated_at
  end
end
