# frozen_string_literal: true

class CreatePositionSuggestionAssignmentLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :position_suggestion_assignment_links do |t|
      t.references :position_suggestion, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.string :action, null: false
      t.string :assignment_type, null: false
      t.integer :min_estimated_energy
      t.integer :max_estimated_energy
      t.references :last_modified_by, null: false, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :position_suggestion_assignment_links,
              [:position_suggestion_id, :assignment_id],
              unique: true,
              name: "index_position_suggestion_assignment_links_unique"
  end
end
