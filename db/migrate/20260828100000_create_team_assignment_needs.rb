# frozen_string_literal: true

class CreateTeamAssignmentNeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :team_assignment_needs do |t|
      t.references :team, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.string :need_type, null: false

      t.timestamps
    end

    add_index :team_assignment_needs, [:team_id, :assignment_id], unique: true
    add_index :team_assignment_needs, :need_type

    create_table :team_assignment_coverers do |t|
      t.references :team_assignment_need, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :team_assignment_coverers,
              [:team_assignment_need_id, :company_teammate_id],
              unique: true,
              name: "index_team_assignment_coverers_on_need_and_teammate"
  end
end
