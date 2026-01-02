class AddManagerTeammateIdToEmploymentTenures < ActiveRecord::Migration[8.0]
  def up
    # Add manager_teammate_id column
    add_column :employment_tenures, :manager_teammate_id, :bigint
    add_index :employment_tenures, :manager_teammate_id
    add_foreign_key :employment_tenures, :teammates, column: :manager_teammate_id

    # Migrate existing manager_id data to manager_teammate_id
    if column_exists?(:employment_tenures, :manager_id)
      execute <<-SQL
        UPDATE employment_tenures
        SET manager_teammate_id = (
          SELECT teammates.id
          FROM teammates
          WHERE teammates.person_id = employment_tenures.manager_id
            AND teammates.organization_id = employment_tenures.company_id
            AND teammates.type = 'CompanyTeammate'
          LIMIT 1
        )
        WHERE manager_id IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM teammates
            WHERE teammates.person_id = employment_tenures.manager_id
              AND teammates.organization_id = employment_tenures.company_id
              AND teammates.type = 'CompanyTeammate'
          );
      SQL

      # Log warning for any records where manager_id exists but CompanyTeammate doesn't
      missing_count = connection.select_value(<<-SQL)
        SELECT COUNT(*)
        FROM employment_tenures
        WHERE manager_id IS NOT NULL
          AND manager_teammate_id IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM teammates
            WHERE teammates.person_id = employment_tenures.manager_id
              AND teammates.organization_id = employment_tenures.company_id
              AND teammates.type = 'CompanyTeammate'
          );
      SQL

      if missing_count > 0
        say "WARNING: #{missing_count} employment tenures have manager_id but no corresponding CompanyTeammate found. manager_teammate_id set to NULL.", true
      end
    end
  end

  def down
    remove_foreign_key :employment_tenures, :teammates, column: :manager_teammate_id
    remove_index :employment_tenures, :manager_teammate_id
    remove_column :employment_tenures, :manager_teammate_id
  end
end

