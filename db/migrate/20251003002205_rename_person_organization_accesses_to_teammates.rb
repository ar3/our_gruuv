class RenamePersonOrganizationAccessesToTeammates < ActiveRecord::Migration[8.0]
  def up
    # Rename the table
    rename_table :person_organization_accesses, :teammates
    
    # Add new columns for employment state and followable functionality
    add_column :teammates, :first_employed_at, :datetime
    add_column :teammates, :last_terminated_at, :datetime
    add_column :teammates, :became_followable_at, :datetime
    
    # Add indexes for the new columns
    add_index :teammates, :first_employed_at
    add_index :teammates, :last_terminated_at
    add_index :teammates, :became_followable_at
    
    # Add index for employment state queries
    add_index :teammates, [:first_employed_at, :last_terminated_at]
  end

  def down
    # Remove the new columns and indexes
    remove_index :teammates, [:first_employed_at, :last_terminated_at]
    remove_index :teammates, :became_followable_at
    remove_index :teammates, :last_terminated_at
    remove_index :teammates, :first_employed_at
    
    remove_column :teammates, :became_followable_at
    remove_column :teammates, :last_terminated_at
    remove_column :teammates, :first_employed_at
    
    # Rename the table back
    rename_table :teammates, :person_organization_accesses
  end
end
