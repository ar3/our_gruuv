class UpdateTitlesForDepartmentSeparation < ActiveRecord::Migration[8.0]
  def up
    # First, update organization_id to point to the root company for titles that belonged to departments
    # Then rename organization_id to company_id
    
    # For titles where organization was a Department, set organization_id to the root company
    execute <<-SQL
      UPDATE titles
      SET organization_id = (
        WITH RECURSIVE org_hierarchy AS (
          SELECT id, parent_id, type
          FROM organizations
          WHERE id = titles.organization_id
          UNION ALL
          SELECT org.id, org.parent_id, org.type
          FROM organizations org
          INNER JOIN org_hierarchy oh ON org.id = oh.parent_id
        )
        SELECT id FROM org_hierarchy WHERE type = 'Company' LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1 FROM organizations WHERE id = titles.organization_id AND type = 'Department'
      )
    SQL

    # Rename organization_id to company_id
    rename_column :titles, :organization_id, :company_id

    # Handle unique index
    if index_exists?(:titles, [:company_id, :position_major_level_id, :external_title], name: "index_position_types_on_org_level_title_unique")
      remove_index :titles, name: "index_position_types_on_org_level_title_unique"
    end
    unless index_exists?(:titles, [:company_id, :position_major_level_id, :external_title], name: "index_titles_on_company_level_title_unique")
      add_index :titles, [:company_id, :position_major_level_id, :external_title], unique: true, name: "index_titles_on_company_level_title_unique"
    end

    # Handle single-column index
    if index_exists?(:titles, :company_id, name: "index_titles_on_organization_id")
      remove_index :titles, name: "index_titles_on_organization_id"
    end
    unless index_exists?(:titles, :company_id, name: "index_titles_on_company_id")
      add_index :titles, :company_id, name: "index_titles_on_company_id"
    end

    # Now update department_id to reference the new departments table
    # Map old Organization-based department_id to new Department-based department_id
    execute <<-SQL
      UPDATE titles
      SET department_id = d.id
      FROM departments d
      WHERE d.migrate_from_organization_id = titles.department_id
        AND titles.department_id IS NOT NULL
    SQL

    # Remove old foreign key for department_id (if exists) and add new one
    begin
      remove_foreign_key :titles, column: :department_id
    rescue ActiveRecord::StatementInvalid
      # Foreign key may not exist
    end
    add_foreign_key :titles, :departments, column: :department_id

    # Add foreign key for company_id
    add_foreign_key :titles, :organizations, column: :company_id
  end

  def down
    # Remove foreign keys
    remove_foreign_key :titles, column: :company_id
    remove_foreign_key :titles, column: :department_id

    # Reverse department_id mapping
    execute <<-SQL
      UPDATE titles
      SET department_id = d.migrate_from_organization_id
      FROM departments d
      WHERE d.id = titles.department_id
        AND titles.department_id IS NOT NULL
    SQL

    # Rename indexes back
    if index_exists?(:titles, :company_id, name: "index_titles_on_company_id")
      remove_index :titles, name: "index_titles_on_company_id"
    end
    unless index_exists?(:titles, :company_id, name: "index_titles_on_organization_id")
      add_index :titles, :company_id, name: "index_titles_on_organization_id"
    end

    if index_exists?(:titles, [:company_id, :position_major_level_id, :external_title], name: "index_titles_on_company_level_title_unique")
      remove_index :titles, name: "index_titles_on_company_level_title_unique"
    end
    unless index_exists?(:titles, [:company_id, :position_major_level_id, :external_title], name: "index_position_types_on_org_level_title_unique")
      add_index :titles, [:company_id, :position_major_level_id, :external_title], unique: true, name: "index_position_types_on_org_level_title_unique"
    end

    # Rename column back
    rename_column :titles, :company_id, :organization_id

    # Note: The data transformation for organization_id is not reversible
    # since we don't know which Department the title originally belonged to
  end
end
