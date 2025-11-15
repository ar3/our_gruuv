class RemoveBecamePublicAtFromMaapResources < ActiveRecord::Migration[8.0]
  def change
    # Remove became_public_at from abilities
    remove_index :abilities, :became_public_at, if_exists: true
    remove_column :abilities, :became_public_at, :datetime, if_exists: true
    
    # Remove became_public_at from assignments
    remove_index :assignments, :became_public_at, if_exists: true
    remove_column :assignments, :became_public_at, :datetime, if_exists: true
    
    # Remove became_public_at from positions
    remove_index :positions, :became_public_at, if_exists: true
    remove_column :positions, :became_public_at, :datetime, if_exists: true
  end
end
