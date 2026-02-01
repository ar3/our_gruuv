class UpdateAspirationsForDepartmentSeparation < ActiveRecord::Migration[8.0]
  def up
    # Add department_id column (references new departments table)
    add_reference :aspirations, :department, foreign_key: true

    # Rename organization_id to company_id
    rename_column :aspirations, :organization_id, :company_id

    # Handle unique index
    if index_exists?(:aspirations, [:company_id, :name], name: "index_aspirations_on_organization_id_and_name")
      remove_index :aspirations, name: "index_aspirations_on_organization_id_and_name"
    end
    unless index_exists?(:aspirations, [:company_id, :name], name: "index_aspirations_on_company_id_and_name")
      add_index :aspirations, [:company_id, :name], unique: true, name: "index_aspirations_on_company_id_and_name"
    end

    # Handle single-column index
    if index_exists?(:aspirations, :company_id, name: "index_aspirations_on_organization_id")
      remove_index :aspirations, name: "index_aspirations_on_organization_id"
    end
    unless index_exists?(:aspirations, :company_id, name: "index_aspirations_on_company_id")
      add_index :aspirations, :company_id, name: "index_aspirations_on_company_id"
    end

    # Migrate data: set department_id for aspirations that belonged to Department organizations
    # Also update company_id to point to the root company
    execute <<-SQL
      UPDATE aspirations
      SET 
        department_id = d.id,
        company_id = d.company_id
      FROM departments d
      WHERE d.migrate_from_organization_id = aspirations.company_id
    SQL

    # Add foreign key for company_id (to organizations table)
    add_foreign_key :aspirations, :organizations, column: :company_id
  end

  def down
    # Remove foreign key for company_id
    remove_foreign_key :aspirations, column: :company_id

    # Reverse the data migration
    execute <<-SQL
      UPDATE aspirations
      SET company_id = d.migrate_from_organization_id
      FROM departments d
      WHERE aspirations.department_id = d.id
    SQL

    # Rename indexes back
    if index_exists?(:aspirations, :company_id, name: "index_aspirations_on_company_id")
      remove_index :aspirations, name: "index_aspirations_on_company_id"
    end
    unless index_exists?(:aspirations, :company_id, name: "index_aspirations_on_organization_id")
      add_index :aspirations, :company_id, name: "index_aspirations_on_organization_id"
    end

    if index_exists?(:aspirations, [:company_id, :name], name: "index_aspirations_on_company_id_and_name")
      remove_index :aspirations, name: "index_aspirations_on_company_id_and_name"
    end
    unless index_exists?(:aspirations, [:company_id, :name], name: "index_aspirations_on_organization_id_and_name")
      add_index :aspirations, [:company_id, :name], unique: true, name: "index_aspirations_on_organization_id_and_name"
    end

    # Rename column back
    rename_column :aspirations, :company_id, :organization_id

    # Remove department_id
    remove_reference :aspirations, :department
  end
end
