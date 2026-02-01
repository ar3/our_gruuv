class MigrateTeamOrganizationsToTeams < ActiveRecord::Migration[8.0]
  def up
    # Migrate Organizations with type='Team' to new teams table
    execute <<-SQL
      INSERT INTO teams (company_id, name, migrate_from_organization_id, deleted_at, created_at, updated_at)
      SELECT parent_id, name, id, deleted_at, created_at, updated_at
      FROM organizations
      WHERE type = 'Team'
        AND parent_id IS NOT NULL
    SQL

    # Migrate TeamTeammates to team_members
    # We need to find the corresponding CompanyTeammate for each TeamTeammate
    # The CompanyTeammate should belong to the same person and the parent company
    execute <<-SQL
      INSERT INTO team_members (team_id, company_teammate_id, migrate_from_teammate_id, created_at, updated_at)
      SELECT t.id, ct.id, tm.id, tm.created_at, tm.updated_at
      FROM teammates tm
      INNER JOIN organizations o ON tm.organization_id = o.id
      INNER JOIN teams t ON t.migrate_from_organization_id = o.id
      INNER JOIN teammates ct ON ct.person_id = tm.person_id
        AND ct.organization_id = o.parent_id
        AND ct.type = 'CompanyTeammate'
      WHERE tm.type = 'TeamTeammate'
    SQL
  end

  def down
    # Remove migrated team_members (those with migrate_from_teammate_id set)
    execute "DELETE FROM team_members WHERE migrate_from_teammate_id IS NOT NULL"

    # Remove migrated teams (those with migrate_from_organization_id set)
    execute "DELETE FROM teams WHERE migrate_from_organization_id IS NOT NULL"
  end
end
