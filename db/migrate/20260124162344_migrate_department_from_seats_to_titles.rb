class MigrateDepartmentFromSeatsToTitles < ActiveRecord::Migration[8.0]
  def up
    # Migrate department_id from seats to titles
    # For each seat, update its title's department_id if the seat has a department
    # If multiple seats with the same title have different departments, use the most common one
    execute <<-SQL
      UPDATE titles
      SET department_id = (
        SELECT department_id
        FROM seats
        WHERE seats.title_id = titles.id
          AND seats.department_id IS NOT NULL
        GROUP BY department_id
        ORDER BY COUNT(*) DESC
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1
        FROM seats
        WHERE seats.title_id = titles.id
          AND seats.department_id IS NOT NULL
      )
    SQL
  end

  def down
    # This migration is not easily reversible without losing data
    # We'll just set department_id to null
    execute <<-SQL
      UPDATE titles
      SET department_id = NULL
    SQL
  end
end
