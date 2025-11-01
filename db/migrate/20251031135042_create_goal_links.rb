class CreateGoalLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_links do |t|
      t.references :this_goal, null: false, foreign_key: { to_table: :goals }
      t.references :that_goal, null: false, foreign_key: { to_table: :goals }
      t.string :link_type, null: false
      t.jsonb :metadata
      
      t.timestamps
    end
    
    # Indexes
    add_index :goal_links, :this_goal_id, if_not_exists: true
    add_index :goal_links, :that_goal_id, if_not_exists: true
    add_index :goal_links, :link_type, if_not_exists: true
    add_index :goal_links, [:this_goal_id, :that_goal_id, :link_type], unique: true, name: 'index_goal_links_unique', if_not_exists: true
  end
end
