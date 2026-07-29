# frozen_string_literal: true

class CreatePositionChangeEligibilityResults < ActiveRecord::Migration[8.0]
  def change
    create_table :position_change_eligibility_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.references :position, null: false, foreign_key: true
      t.text :output_text
      t.text :manager_only_output_text
      t.text :teammate_only_output_text
      t.boolean :manager_only_ran, null: false, default: false
      t.boolean :teammate_only_ran, null: false, default: false
      t.string :change_type
      t.timestamps
    end
  end
end
