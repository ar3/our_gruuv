class RemoveOrganizationIdFromHuddlePlaybooks < ActiveRecord::Migration[8.0]
  def up
    # First, ensure all playbooks have a company_id set
    # Any remaining nulls should be set from organization_id
    execute <<-SQL
      UPDATE huddle_playbooks
      SET company_id = organization_id
      WHERE company_id IS NULL AND organization_id IS NOT NULL
    SQL

    # Remove the unique index that includes organization_id
    remove_index :huddle_playbooks, name: :index_huddle_playbooks_on_org_and_special_session_name_unique, if_exists: true
    
    # Remove the organization_id index
    remove_index :huddle_playbooks, :organization_id, if_exists: true
    
    # Remove the organization_id column
    remove_column :huddle_playbooks, :organization_id

    # Add a new unique index on company_id, team_id, and special_session_name
    # This allows different teams in the same company to have playbooks with the same name
    add_index :huddle_playbooks, [:company_id, :team_id, :special_session_name], 
              name: :index_huddle_playbooks_on_company_team_and_session_name, 
              unique: true

    # Make company_id not null now that migration is complete
    change_column_null :huddle_playbooks, :company_id, false
  end

  def down
    # Make company_id nullable again
    change_column_null :huddle_playbooks, :company_id, true

    # Remove the new unique index
    remove_index :huddle_playbooks, name: :index_huddle_playbooks_on_company_team_and_session_name, if_exists: true

    # Add back organization_id column
    add_column :huddle_playbooks, :organization_id, :bigint

    # Copy company_id to organization_id
    execute "UPDATE huddle_playbooks SET organization_id = company_id"

    # Make organization_id not null
    change_column_null :huddle_playbooks, :organization_id, false

    # Add back the indexes
    add_index :huddle_playbooks, :organization_id
    add_index :huddle_playbooks, [:organization_id, :special_session_name], 
              name: :index_huddle_playbooks_on_org_and_special_session_name_unique, 
              unique: true
  end
end
