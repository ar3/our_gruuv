class NormalizeSpecialSessionNamesAndAddUniqueConstraint < ActiveRecord::Migration[7.1]
  def up
    # First, normalize all nil values to empty strings for consistency
    # This ensures we have a consistent state before adding the constraint
    execute <<-SQL
      UPDATE huddle_playbooks 
      SET special_session_name = '' 
      WHERE special_session_name IS NULL
    SQL

    # Remove any existing index that might conflict
    remove_index :huddle_playbooks, [:organization_id, :special_session_name], if_exists: true

    # Add a unique constraint that treats empty strings as unique per organization
    # This prevents multiple playbooks with empty special_session_name per organization
    add_index :huddle_playbooks, [:organization_id, :special_session_name], 
              unique: true, 
              name: 'index_huddle_playbooks_on_org_and_special_session_name_unique'
  end

  def down
    # Remove the unique constraint
    remove_index :huddle_playbooks, name: 'index_huddle_playbooks_on_org_and_special_session_name_unique'
    
    # Restore the original non-unique index if needed
    add_index :huddle_playbooks, [:organization_id, :special_session_name], 
              name: 'index_huddle_playbooks_on_org_and_special_session_name'
  end
end
