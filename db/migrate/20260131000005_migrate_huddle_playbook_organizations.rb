class MigrateHuddlePlaybookOrganizations < ActiveRecord::Migration[8.0]
  def up
    # For playbooks belonging to Teams (via migrate_from_organization_id), set company_id and team_id
    execute <<-SQL
      UPDATE huddle_playbooks
      SET company_id = t.company_id,
          team_id = t.id
      FROM teams t
      WHERE t.migrate_from_organization_id = huddle_playbooks.organization_id
    SQL

    # For playbooks belonging to Companies directly, set company_id only
    execute <<-SQL
      UPDATE huddle_playbooks
      SET company_id = huddle_playbooks.organization_id
      FROM organizations o
      WHERE o.id = huddle_playbooks.organization_id
        AND o.type = 'Company'
        AND huddle_playbooks.company_id IS NULL
    SQL

    # For playbooks belonging to Departments, set company_id to the department's parent (the company)
    execute <<-SQL
      UPDATE huddle_playbooks
      SET company_id = o.parent_id
      FROM organizations o
      WHERE o.id = huddle_playbooks.organization_id
        AND o.type = 'Department'
        AND huddle_playbooks.company_id IS NULL
    SQL
  end

  def down
    # Reset the company_id and team_id columns
    execute "UPDATE huddle_playbooks SET company_id = NULL, team_id = NULL"
  end
end
