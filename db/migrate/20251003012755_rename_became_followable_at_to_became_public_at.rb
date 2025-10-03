class RenameBecameFollowableAtToBecamePublicAt < ActiveRecord::Migration[8.0]
  def up
    # Rename became_followable_at to became_public_at for assignments
    remove_index :assignments, :became_followable_at
    rename_column :assignments, :became_followable_at, :became_public_at
    add_index :assignments, :became_public_at
    
    # Rename became_followable_at to became_public_at for abilities
    remove_index :abilities, :became_followable_at
    rename_column :abilities, :became_followable_at, :became_public_at
    add_index :abilities, :became_public_at
    
    # Rename became_followable_at to became_public_at for positions
    remove_index :positions, :became_followable_at
    rename_column :positions, :became_followable_at, :became_public_at
    add_index :positions, :became_public_at
  end

  def down
    # Rename became_public_at back to became_followable_at for positions
    remove_index :positions, :became_public_at
    rename_column :positions, :became_public_at, :became_followable_at
    add_index :positions, :became_followable_at
    
    # Rename became_public_at back to became_followable_at for abilities
    remove_index :abilities, :became_public_at
    rename_column :abilities, :became_public_at, :became_followable_at
    add_index :abilities, :became_followable_at
    
    # Rename became_public_at back to became_followable_at for assignments
    remove_index :assignments, :became_public_at
    rename_column :assignments, :became_public_at, :became_followable_at
    add_index :assignments, :became_followable_at
  end
end
