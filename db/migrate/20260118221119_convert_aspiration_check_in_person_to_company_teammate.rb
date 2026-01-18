class ConvertAspirationCheckInPersonToCompanyTeammate < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraints that will prevent updating the columns
    # Find and remove manager_completed_by_id foreign key
    manager_fk = ActiveRecord::Base.connection.foreign_keys('aspiration_check_ins').find { |fk| fk.column == 'manager_completed_by_id' }
    if manager_fk && foreign_key_exists?(:aspiration_check_ins, :people, column: :manager_completed_by_id, name: manager_fk.name)
      remove_foreign_key :aspiration_check_ins, :people, column: :manager_completed_by_id, name: manager_fk.name
    end
    
    # Find and remove finalized_by_id foreign key
    finalized_fk = ActiveRecord::Base.connection.foreign_keys('aspiration_check_ins').find { |fk| fk.column == 'finalized_by_id' }
    if finalized_fk && foreign_key_exists?(:aspiration_check_ins, :people, column: :finalized_by_id, name: finalized_fk.name)
      remove_foreign_key :aspiration_check_ins, :people, column: :finalized_by_id, name: finalized_fk.name
    end
    
    # Add new columns
    add_column :aspiration_check_ins, :manager_completed_by_teammate_id, :bigint
    add_column :aspiration_check_ins, :finalized_by_teammate_id, :bigint
    
    # Add indexes
    add_index :aspiration_check_ins, :manager_completed_by_teammate_id
    add_index :aspiration_check_ins, :finalized_by_teammate_id
    
    # Migrate manager_completed_by_id to manager_completed_by_teammate_id
    AspirationCheckIn.where.not(manager_completed_by_id: nil).find_each do |check_in|
      person_id = check_in.manager_completed_by_id
      # Get company_id from the teammate's organization
      company_id = check_in.teammate.organization_id
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        check_in.update_columns(
          manager_completed_by_teammate_id: company_teammate.id,
          manager_completed_by_id: -1 * check_in.manager_completed_by_id
        )
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for aspiration_check_in_id=#{check_in.id}")
        # Still invalidate the old field
        check_in.update_column(:manager_completed_by_id, -1 * check_in.manager_completed_by_id)
      end
    end
    
    # Migrate finalized_by_id to finalized_by_teammate_id
    AspirationCheckIn.where.not(finalized_by_id: nil).find_each do |check_in|
      person_id = check_in.finalized_by_id
      # Get company_id from the teammate's organization
      company_id = check_in.teammate.organization_id
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        check_in.update_columns(
          finalized_by_teammate_id: company_teammate.id,
          finalized_by_id: -1 * check_in.finalized_by_id
        )
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for aspiration_check_in_id=#{check_in.id}")
        # Still invalidate the old field
        check_in.update_column(:finalized_by_id, -1 * check_in.finalized_by_id)
      end
    end
  end
  
  def down
    # Migrate back (if needed for rollback)
    AspirationCheckIn.where.not(manager_completed_by_teammate_id: nil).find_each do |check_in|
      company_teammate = CompanyTeammate.find_by(id: check_in.manager_completed_by_teammate_id)
      if company_teammate
        check_in.update_column(:manager_completed_by_id, company_teammate.person_id)
      end
    end
    
    AspirationCheckIn.where.not(finalized_by_teammate_id: nil).find_each do |check_in|
      company_teammate = CompanyTeammate.find_by(id: check_in.finalized_by_teammate_id)
      if company_teammate
        check_in.update_column(:finalized_by_id, company_teammate.person_id)
      end
    end
    
    # Remove indexes
    remove_index :aspiration_check_ins, :manager_completed_by_teammate_id
    remove_index :aspiration_check_ins, :finalized_by_teammate_id
    
    # Remove columns
    remove_column :aspiration_check_ins, :manager_completed_by_teammate_id
    remove_column :aspiration_check_ins, :finalized_by_teammate_id
    
    # Re-add foreign key constraints if rolling back
    manager_fk = ActiveRecord::Base.connection.foreign_keys('aspiration_check_ins').find { |fk| fk.column == 'manager_completed_by_id' }
    if manager_fk && !foreign_key_exists?(:aspiration_check_ins, :people, column: :manager_completed_by_id, name: manager_fk.name)
      add_foreign_key :aspiration_check_ins, :people, column: :manager_completed_by_id, name: manager_fk.name
    end
    
    finalized_fk = ActiveRecord::Base.connection.foreign_keys('aspiration_check_ins').find { |fk| fk.column == 'finalized_by_id' }
    if finalized_fk && !foreign_key_exists?(:aspiration_check_ins, :people, column: :finalized_by_id, name: finalized_fk.name)
      add_foreign_key :aspiration_check_ins, :people, column: :finalized_by_id, name: finalized_fk.name
    end
  end
end
