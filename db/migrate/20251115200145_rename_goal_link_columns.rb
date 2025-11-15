class RenameGoalLinkColumns < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign keys
    remove_foreign_key :goal_links, :goals, column: :this_goal_id
    remove_foreign_key :goal_links, :goals, column: :that_goal_id
    
    # Remove indexes that reference the old column names
    remove_index :goal_links, :this_goal_id, if_exists: true
    remove_index :goal_links, :that_goal_id, if_exists: true
    remove_index :goal_links, name: 'index_goal_links_unique', if_exists: true
    
    # Rename columns
    rename_column :goal_links, :this_goal_id, :parent_id
    rename_column :goal_links, :that_goal_id, :child_id
    
    # Add foreign keys with new column names
    add_foreign_key :goal_links, :goals, column: :parent_id
    add_foreign_key :goal_links, :goals, column: :child_id
    
    # Recreate indexes with new column names
    add_index :goal_links, :parent_id, if_not_exists: true
    add_index :goal_links, :child_id, if_not_exists: true
    add_index :goal_links, [:parent_id, :child_id], unique: true, name: 'index_goal_links_unique', if_not_exists: true
  end
  
  def down
    # Remove foreign keys
    remove_foreign_key :goal_links, :goals, column: :parent_id
    remove_foreign_key :goal_links, :goals, column: :child_id
    
    # Remove indexes
    remove_index :goal_links, :parent_id, if_exists: true
    remove_index :goal_links, :child_id, if_exists: true
    remove_index :goal_links, name: 'index_goal_links_unique', if_exists: true
    
    # Rename columns back
    rename_column :goal_links, :parent_id, :this_goal_id
    rename_column :goal_links, :child_id, :that_goal_id
    
    # Add foreign keys back
    add_foreign_key :goal_links, :goals, column: :this_goal_id
    add_foreign_key :goal_links, :goals, column: :that_goal_id
    
    # Recreate indexes
    add_index :goal_links, :this_goal_id, if_not_exists: true
    add_index :goal_links, :that_goal_id, if_not_exists: true
    add_index :goal_links, :link_type, if_not_exists: true
    add_index :goal_links, [:this_goal_id, :that_goal_id, :link_type], unique: true, name: 'index_goal_links_unique', if_not_exists: true
  end
end
