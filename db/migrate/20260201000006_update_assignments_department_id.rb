class UpdateAssignmentsDepartmentId < ActiveRecord::Migration[8.0]
  def up
    # Map old Organization-based department_id to new Department-based department_id
    execute <<-SQL
      UPDATE assignments
      SET department_id = d.id
      FROM departments d
      WHERE d.migrate_from_organization_id = assignments.department_id
        AND assignments.department_id IS NOT NULL
    SQL

    # Remove old foreign key (if exists) and add new one
    begin
      remove_foreign_key :assignments, column: :department_id
    rescue ActiveRecord::StatementInvalid
      # Foreign key may not exist
    end
    add_foreign_key :assignments, :departments, column: :department_id
  end

  def down
    # Remove new foreign key
    remove_foreign_key :assignments, column: :department_id

    # Reverse department_id mapping
    execute <<-SQL
      UPDATE assignments
      SET department_id = d.migrate_from_organization_id
      FROM departments d
      WHERE d.id = assignments.department_id
        AND assignments.department_id IS NOT NULL
    SQL
  end
end
