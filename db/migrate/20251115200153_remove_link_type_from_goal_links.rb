class RemoveLinkTypeFromGoalLinks < ActiveRecord::Migration[8.0]
  def up
    # Remove link_type index
    remove_index :goal_links, :link_type, if_exists: true
    
    # Remove link_type column
    remove_column :goal_links, :link_type, :string
  end
  
  def down
    # Add link_type column back
    add_column :goal_links, :link_type, :string, null: false, default: 'this_is_key_result_of_that'
    
    # Recreate link_type index
    add_index :goal_links, :link_type, if_not_exists: true
    
    # Update unique index to include link_type again
    remove_index :goal_links, name: 'index_goal_links_unique', if_exists: true
    add_index :goal_links, [:parent_id, :child_id, :link_type], unique: true, name: 'index_goal_links_unique', if_not_exists: true
  end
end
