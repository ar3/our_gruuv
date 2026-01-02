class RemoveManagerIdFromEmploymentTenures < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key if it exists
    if foreign_key_exists?(:employment_tenures, :people, column: :manager_id)
      remove_foreign_key :employment_tenures, column: :manager_id
    end
    
    # Remove index if it exists
    if index_exists?(:employment_tenures, :manager_id)
      remove_index :employment_tenures, :manager_id
    end
    
    # Remove the column
    remove_column :employment_tenures, :manager_id
  end

  def down
    # Add the column back
    add_column :employment_tenures, :manager_id, :bigint
    
    # Add index
    add_index :employment_tenures, :manager_id
    
    # Add foreign key
    add_foreign_key :employment_tenures, :people, column: :manager_id
    
    # Migrate data back from manager_teammate_id to manager_id
    say_with_time "Migrating manager_teammate_id back to manager_id" do
      EmploymentTenure.reset_column_information
      EmploymentTenure.find_each do |tenure|
        if tenure.manager_teammate_id.present?
          manager_teammate = CompanyTeammate.find_by(id: tenure.manager_teammate_id)
          if manager_teammate
            tenure.update_column(:manager_id, manager_teammate.person_id)
          end
        end
      end
    end
  end
end
