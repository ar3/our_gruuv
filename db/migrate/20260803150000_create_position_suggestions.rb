class CreatePositionSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :position_suggestions do |t|
      t.references :position, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.references :opened_by, null: false, foreign_key: { to_table: :teammates }
      t.references :closed_by, null: true, foreign_key: { to_table: :teammates }
      t.datetime :closed_at

      t.timestamps
    end

    add_index :position_suggestions, :status
    add_index :position_suggestions, [:position_id, :status],
              unique: true,
              where: "status = 'open'",
              name: "index_position_suggestions_one_open_per_position"

    create_table :position_suggestion_participants do |t|
      t.references :position_suggestion, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :participation_status, null: false, default: "active"

      t.timestamps
    end

    add_index :position_suggestion_participants,
              [:position_suggestion_id, :company_teammate_id],
              unique: true,
              name: "index_position_suggestion_participants_unique"

    create_table :position_suggestion_milestones do |t|
      t.references :position_suggestion, null: false, foreign_key: true
      # Polymorphic: AssignmentAbility today; PositionAbility / Ability later ("direct" milestones).
      t.references :milestoneable, polymorphic: true, null: false
      t.integer :suggested_milestone_level, null: false
      t.references :last_modified_by, null: false, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :position_suggestion_milestones,
              [:position_suggestion_id, :milestoneable_type, :milestoneable_id],
              unique: true,
              name: "index_position_suggestion_milestones_unique"

    add_reference :comments, :position_suggestion, null: true, foreign_key: true
  end
end
