class RemoveTypeFromOrganizations < ActiveRecord::Migration[8.0]
  def up
    # Remove any legacy Team/Department records that might still exist
    # These have been migrated to their own tables
    execute <<-SQL
      DELETE FROM organizations WHERE type IN ('Team', 'Department');
    SQL

    # Remove the STI type column
    remove_column :organizations, :type
  end

  def down
    add_column :organizations, :type, :string

    # Set all existing records to Company type
    execute <<-SQL
      UPDATE organizations SET type = 'Company';
    SQL
  end
end
