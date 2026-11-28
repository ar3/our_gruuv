# frozen_string_literal: true

class CreateTeamPrimaryOutcomes < ActiveRecord::Migration[8.0]
  def change
    create_table :team_primary_outcomes do |t|
      t.references :team, null: false, foreign_key: true
      t.references :assignment_outcome, null: false, foreign_key: true

      t.timestamps
    end

    add_index :team_primary_outcomes, [:team_id, :assignment_outcome_id],
              unique: true,
              name: "index_team_primary_outcomes_on_team_and_outcome"
  end
end
