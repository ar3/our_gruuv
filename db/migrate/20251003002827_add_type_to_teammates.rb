class AddTypeToTeammates < ActiveRecord::Migration[8.0]
  def up
    # Only add the column if the table exists and the column doesn't already exist
    if table_exists?(:person_organization_accesses) && !table_exists?(:teammates)
      rename_table :person_organization_accesses, :teammates
    end

    if table_exists?(:teammates) && !column_exists?(:teammates, :type)
      add_column :teammates, :type, :string
    end
  end

  def down
    # Only remove the column if it exists
    if table_exists?(:teammates) && column_exists?(:teammates, :type)
      remove_column :teammates, :type
    end
  end
end
