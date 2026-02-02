# frozen_string_literal: true

class PointSeatsTeamIdToTeams < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :seats, :organizations, column: :team_id
    add_column :seats, :new_team_id, :bigint
    execute <<-SQL.squish
      UPDATE seats s
      SET new_team_id = t.id
      FROM teams t
      WHERE t.migrate_from_organization_id = s.team_id
        AND s.team_id IS NOT NULL
    SQL
    remove_column :seats, :team_id
    rename_column :seats, :new_team_id, :team_id
    add_index :seats, :team_id
    add_foreign_key :seats, :teams, column: :team_id
  end

  def down
    remove_foreign_key :seats, :teams, column: :team_id
    remove_index :seats, :team_id
    add_column :seats, :old_team_id, :bigint
    execute <<-SQL.squish
      UPDATE seats s
      SET old_team_id = t.migrate_from_organization_id
      FROM teams t
      WHERE t.id = s.team_id
        AND s.team_id IS NOT NULL
    SQL
    remove_column :seats, :team_id
    rename_column :seats, :old_team_id, :team_id
    add_index :seats, :team_id
    add_foreign_key :seats, :organizations, column: :team_id
  end
end
