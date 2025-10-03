class AddBecameFollowableAtToAssignmentsAbilitiesPositions < ActiveRecord::Migration[8.0]
  def up
    # Add became_followable_at to assignments
    add_column :assignments, :became_followable_at, :datetime
    add_index :assignments, :became_followable_at
    
    # Add became_followable_at to abilities
    add_column :abilities, :became_followable_at, :datetime
    add_index :abilities, :became_followable_at
    
    # Add became_followable_at to positions
    add_column :positions, :became_followable_at, :datetime
    add_index :positions, :became_followable_at
  end

  def down
    # Remove became_followable_at from positions
    remove_index :positions, :became_followable_at
    remove_column :positions, :became_followable_at
    
    # Remove became_followable_at from abilities
    remove_index :abilities, :became_followable_at
    remove_column :abilities, :became_followable_at
    
    # Remove became_followable_at from assignments
    remove_index :assignments, :became_followable_at
    remove_column :assignments, :became_followable_at
  end
end
