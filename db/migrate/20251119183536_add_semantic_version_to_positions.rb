class AddSemanticVersionToPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :positions, :semantic_version, :string, default: "0.0.1", null: false
    
    # Backfill existing records with "0.0.1"
    execute <<-SQL
      UPDATE positions SET semantic_version = '0.0.1' WHERE semantic_version IS NULL;
    SQL
  end
end


