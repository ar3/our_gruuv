class RemoveBecameFollowableAtFromTeammates < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:person_organization_accesses) && !table_exists?(:teammates)
      rename_table :person_organization_accesses, :teammates
    end
    
    # Check if the index exists before trying to remove it
    if index_exists?(:teammates, :became_followable_at)
      remove_index :teammates, :became_followable_at
    end
    
    # Check if the column exists before trying to remove it
    if column_exists?(:teammates, :became_followable_at)
      remove_column :teammates, :became_followable_at
    end
  end

  def down
    # Check if the column doesn't exist before adding it
    unless column_exists?(:teammates, :became_followable_at)
      add_column :teammates, :became_followable_at, :datetime
    end
    
    # Check if the index doesn't exist before adding it
    unless index_exists?(:teammates, :became_followable_at)
      add_index :teammates, :became_followable_at
    end
  end
end
