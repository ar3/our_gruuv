class AddExpiresAtToHuddles < ActiveRecord::Migration[8.0]
  def change
    # Add the column as nullable first so we can populate existing records
    add_column :huddles, :expires_at, :datetime
    
    # Update all existing huddles to expire 24 hours after they started
    execute <<-SQL
      UPDATE huddles 
      SET expires_at = started_at + INTERVAL '24 hours'
      WHERE expires_at IS NULL
    SQL
    
    # Now make it non-nullable and add the default for future records
    change_column_null :huddles, :expires_at, false
    change_column_default :huddles, :expires_at, from: nil, to: -> { 'CURRENT_TIMESTAMP + INTERVAL \'24 hours\'' }
    
    # Add index for performance
    add_index :huddles, :expires_at
  end
end
