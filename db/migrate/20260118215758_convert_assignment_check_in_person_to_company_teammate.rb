class ConvertAssignmentCheckInPersonToCompanyTeammate < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraints that will prevent updating the columns
    remove_foreign_key :assignment_check_ins, :people, column: :finalized_by_id, name: "fk_rails_6284f30b73" if foreign_key_exists?(:assignment_check_ins, :people, column: :finalized_by_id, name: "fk_rails_6284f30b73")
    
    # Check if manager_completed_by_id foreign key exists and remove it if it does
    # Note: It may not exist based on schema inspection, but we'll check anyway
    manager_fk_name = ActiveRecord::Base.connection.foreign_keys('assignment_check_ins').find { |fk| fk.column == 'manager_completed_by_id' }&.name
    if manager_fk_name && foreign_key_exists?(:assignment_check_ins, :people, column: :manager_completed_by_id, name: manager_fk_name)
      remove_foreign_key :assignment_check_ins, :people, column: :manager_completed_by_id, name: manager_fk_name
    end
    
    # Add new columns
    add_column :assignment_check_ins, :manager_completed_by_teammate_id, :bigint
    add_column :assignment_check_ins, :finalized_by_teammate_id, :bigint
    
    # Add indexes
    add_index :assignment_check_ins, :manager_completed_by_teammate_id
    add_index :assignment_check_ins, :finalized_by_teammate_id
    
    # Migrate manager_completed_by_id to manager_completed_by_teammate_id
    AssignmentCheckIn.where.not(manager_completed_by_id: nil).find_each do |check_in|
      person_id = check_in.manager_completed_by_id
      # Get company_id from the assignment
      company_id = check_in.assignment.company_id
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        check_in.update_columns(
          manager_completed_by_teammate_id: company_teammate.id,
          manager_completed_by_id: -1 * check_in.manager_completed_by_id
        )
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for assignment_check_in_id=#{check_in.id}")
        # Still invalidate the old field
        check_in.update_column(:manager_completed_by_id, -1 * check_in.manager_completed_by_id)
      end
    end
    
    # Migrate finalized_by_id to finalized_by_teammate_id
    AssignmentCheckIn.where.not(finalized_by_id: nil).find_each do |check_in|
      person_id = check_in.finalized_by_id
      # Get company_id from the assignment
      company_id = check_in.assignment.company_id
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        check_in.update_columns(
          finalized_by_teammate_id: company_teammate.id,
          finalized_by_id: -1 * check_in.finalized_by_id
        )
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for assignment_check_in_id=#{check_in.id}")
        # Still invalidate the old field
        check_in.update_column(:finalized_by_id, -1 * check_in.finalized_by_id)
      end
    end
  end
  
  def down
    # Migrate back (if needed for rollback)
    AssignmentCheckIn.where.not(manager_completed_by_teammate_id: nil).find_each do |check_in|
      company_teammate = CompanyTeammate.find_by(id: check_in.manager_completed_by_teammate_id)
      if company_teammate
        check_in.update_column(:manager_completed_by_id, company_teammate.person_id)
      end
    end
    
    AssignmentCheckIn.where.not(finalized_by_teammate_id: nil).find_each do |check_in|
      company_teammate = CompanyTeammate.find_by(id: check_in.finalized_by_teammate_id)
      if company_teammate
        check_in.update_column(:finalized_by_id, company_teammate.person_id)
      end
    end
    
    # Remove indexes
    remove_index :assignment_check_ins, :manager_completed_by_teammate_id
    remove_index :assignment_check_ins, :finalized_by_teammate_id
    
    # Remove columns
    remove_column :assignment_check_ins, :manager_completed_by_teammate_id
    remove_column :assignment_check_ins, :finalized_by_teammate_id
    
    # Re-add foreign key constraints if rolling back
    add_foreign_key :assignment_check_ins, :people, column: :finalized_by_id, name: "fk_rails_6284f30b73" unless foreign_key_exists?(:assignment_check_ins, :people, column: :finalized_by_id, name: "fk_rails_6284f30b73")
  end
end
