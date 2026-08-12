# frozen_string_literal: true

class CreatePositionSuggestionAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :position_suggestion_assignments do |t|
      t.references :position_suggestion, null: false, foreign_key: true
      # Live Assignment being edited. Null reserved for net-new Assignments (later phase).
      t.references :source_assignment, null: false, foreign_key: { to_table: :assignments }
      t.string :title, null: false
      t.text :tagline
      t.text :required_activities
      t.text :handbook
      t.references :last_modified_by, null: false, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :position_suggestion_assignments,
              [:position_suggestion_id, :source_assignment_id],
              unique: true,
              name: "index_position_suggestion_assignments_unique"

    create_table :position_suggestion_assignment_outcomes do |t|
      t.references :position_suggestion_assignment,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ps_assignment_outcomes_on_draft_id" }
      t.text :description, null: false
      t.string :outcome_type, null: false
      t.string :progress_report_url
      t.string :management_relationship_filter
      t.string :team_relationship_filter
      t.string :consumer_assignment_filter
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
