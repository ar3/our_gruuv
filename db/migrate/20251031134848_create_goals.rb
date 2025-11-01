class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      # Polymorphic owner (Person or Organization)
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      
      # Creator (Teammate)
      t.references :creator, null: false, foreign_key: { to_table: :teammates }
      
      # Goal content
      t.string :title, null: false
      t.text :description
      
      # Goal type enum (string-backed)
      t.string :goal_type, null: false
      
      # Target dates (all required)
      t.date :earliest_target_date, null: false
      t.date :latest_target_date, null: false
      t.date :most_likely_target_date, null: false
      
      # Privacy level enum (string-backed)
      t.string :privacy_level, null: false
      
      # Status tracking via datetimes
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.datetime :became_top_priority
      
      # Soft delete
      t.datetime :deleted_at
      
      t.timestamps
    end
    
    # Indexes
    add_index :goals, [:owner_type, :owner_id], if_not_exists: true
    add_index :goals, :creator_id, if_not_exists: true
    add_index :goals, :goal_type, if_not_exists: true
    add_index :goals, :privacy_level, if_not_exists: true
    add_index :goals, :most_likely_target_date, if_not_exists: true
    add_index :goals, :earliest_target_date, if_not_exists: true
    add_index :goals, :latest_target_date, if_not_exists: true
    add_index :goals, :started_at, if_not_exists: true
    add_index :goals, :completed_at, if_not_exists: true
    add_index :goals, :cancelled_at, if_not_exists: true
    add_index :goals, :deleted_at, if_not_exists: true
  end
end
