class AddSemanticVersionToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :assignments, :semantic_version, :string, default: "0.0.1", null: false
    
    # Backfill existing records with "0.0.1"
    execute <<-SQL
      UPDATE assignments SET semantic_version = '0.0.1' WHERE semantic_version IS NULL;
    SQL
  end
end


