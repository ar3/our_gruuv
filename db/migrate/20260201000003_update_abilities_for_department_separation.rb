class UpdateAbilitiesForDepartmentSeparation < ActiveRecord::Migration[8.0]
  def up
    # Add department_id column (references new departments table)
    add_reference :abilities, :department, foreign_key: true

    # Rename organization_id to company_id
    rename_column :abilities, :organization_id, :company_id

    # The unique index name changes when column is renamed, recreate it with correct name
    # First, remove the auto-renamed index (it will have old column name in it)
    if index_exists?(:abilities, [:name, :company_id], name: "index_abilities_on_name_and_organization_id")
      remove_index :abilities, name: "index_abilities_on_name_and_organization_id"
    end
    # Create index with correct name
    unless index_exists?(:abilities, [:name, :company_id], name: "index_abilities_on_name_and_company_id")
      add_index :abilities, [:name, :company_id], unique: true, name: "index_abilities_on_name_and_company_id"
    end

    # Handle the single-column index similarly
    if index_exists?(:abilities, :company_id, name: "index_abilities_on_organization_id")
      remove_index :abilities, name: "index_abilities_on_organization_id"
    end
    unless index_exists?(:abilities, :company_id, name: "index_abilities_on_company_id")
      add_index :abilities, :company_id, name: "index_abilities_on_company_id"
    end

    # Migrate data: set department_id for abilities that belonged to Department organizations
    # Also update company_id to point to the root company
    execute <<-SQL
      UPDATE abilities
      SET 
        department_id = d.id,
        company_id = d.company_id
      FROM departments d
      WHERE d.migrate_from_organization_id = abilities.company_id
    SQL

    # For abilities that belonged to Companies (not Departments), company_id stays the same
    # No update needed for those

    # Add foreign key for company_id (to organizations table)
    add_foreign_key :abilities, :organizations, column: :company_id
  end

  def down
    # Remove foreign key for company_id
    remove_foreign_key :abilities, column: :company_id

    # Reverse the data migration - restore original organization_id from department's migrate_from_organization_id
    execute <<-SQL
      UPDATE abilities
      SET company_id = d.migrate_from_organization_id
      FROM departments d
      WHERE abilities.department_id = d.id
    SQL

    # Rename indexes back
    if index_exists?(:abilities, :company_id, name: "index_abilities_on_company_id")
      remove_index :abilities, name: "index_abilities_on_company_id"
    end
    unless index_exists?(:abilities, :company_id, name: "index_abilities_on_organization_id")
      add_index :abilities, :company_id, name: "index_abilities_on_organization_id"
    end

    if index_exists?(:abilities, [:name, :company_id], name: "index_abilities_on_name_and_company_id")
      remove_index :abilities, name: "index_abilities_on_name_and_company_id"
    end
    unless index_exists?(:abilities, [:name, :company_id], name: "index_abilities_on_name_and_organization_id")
      add_index :abilities, [:name, :company_id], unique: true, name: "index_abilities_on_name_and_organization_id"
    end

    # Rename column back
    rename_column :abilities, :company_id, :organization_id

    # Remove department_id
    remove_reference :abilities, :department
  end
end
