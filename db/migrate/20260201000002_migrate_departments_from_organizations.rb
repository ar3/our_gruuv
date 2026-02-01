class MigrateDepartmentsFromOrganizations < ActiveRecord::Migration[8.0]
  def up
    # First, migrate root departments (those whose parent is a Company)
    # We need to find departments where the parent is a Company (not another Department)
    execute <<-SQL
      INSERT INTO departments (company_id, parent_department_id, name, migrate_from_organization_id, deleted_at, created_at, updated_at)
      SELECT 
        CASE 
          WHEN parent_org.type = 'Company' THEN parent_org.id
          ELSE (
            WITH RECURSIVE org_hierarchy AS (
              SELECT id, parent_id, type
              FROM organizations
              WHERE id = o.parent_id
              UNION ALL
              SELECT org.id, org.parent_id, org.type
              FROM organizations org
              INNER JOIN org_hierarchy oh ON org.id = oh.parent_id
            )
            SELECT id FROM org_hierarchy WHERE type = 'Company' LIMIT 1
          )
        END as company_id,
        NULL as parent_department_id,
        o.name,
        o.id,
        o.deleted_at,
        o.created_at,
        o.updated_at
      FROM organizations o
      INNER JOIN organizations parent_org ON o.parent_id = parent_org.id
      WHERE o.type = 'Department'
        AND parent_org.type = 'Company'
    SQL

    # Then, migrate child departments iteratively
    # We need to keep migrating until no more departments are left
    # This handles arbitrary nesting levels
    loop do
      rows_affected = execute(<<-SQL).cmd_tuples
        INSERT INTO departments (company_id, parent_department_id, name, migrate_from_organization_id, deleted_at, created_at, updated_at)
        SELECT 
          d.company_id,
          d.id as parent_department_id,
          o.name,
          o.id,
          o.deleted_at,
          o.created_at,
          o.updated_at
        FROM organizations o
        INNER JOIN organizations parent_org ON o.parent_id = parent_org.id
        INNER JOIN departments d ON d.migrate_from_organization_id = parent_org.id
        WHERE o.type = 'Department'
          AND parent_org.type = 'Department'
          AND NOT EXISTS (
            SELECT 1 FROM departments WHERE migrate_from_organization_id = o.id
          )
      SQL

      break if rows_affected == 0
    end
  end

  def down
    # Remove all migrated departments
    execute "DELETE FROM departments WHERE migrate_from_organization_id IS NOT NULL"
  end
end
