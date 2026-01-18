class ConvertPositionCheckInPersonToCompanyTeammate < ActiveRecord::Migration[7.1]
  def up
    # Add new columns
    add_column :position_check_ins, :manager_completed_by_teammate_id, :bigint
    add_column :position_check_ins, :finalized_by_teammate_id, :bigint
    
    # Add indexes
    add_index :position_check_ins, :manager_completed_by_teammate_id
    add_index :position_check_ins, :finalized_by_teammate_id
    
    # Migrate manager_completed_by_id to manager_completed_by_teammate_id
    PositionCheckIn.where.not(manager_completed_by_id: nil).find_each do |check_in|
      person_id = check_in.manager_completed_by_id
      company_id = check_in.teammate.organization_id
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        check_in.update_columns(
          manager_completed_by_teammate_id: company_teammate.id,
          manager_completed_by_id: -1 * check_in.manager_completed_by_id
        )
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for position_check_in_id=#{check_in.id}")
        # Still invalidate the old field
        check_in.update_column(:manager_completed_by_id, -1 * check_in.manager_completed_by_id)
      end
    end
    
    # Migrate finalized_by_id to finalized_by_teammate_id
    PositionCheckIn.where.not(finalized_by_id: nil).find_each do |check_in|
      person_id = check_in.finalized_by_id
      company_id = check_in.teammate.organization_id
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        check_in.update_columns(
          finalized_by_teammate_id: company_teammate.id,
          finalized_by_id: -1 * check_in.finalized_by_id
        )
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for position_check_in_id=#{check_in.id}")
        # Still invalidate the old field
        check_in.update_column(:finalized_by_id, -1 * check_in.finalized_by_id)
      end
    end
  end
  
  def down
    # Migrate back (if needed for rollback)
    PositionCheckIn.where.not(manager_completed_by_teammate_id: nil).find_each do |check_in|
      company_teammate = CompanyTeammate.find_by(id: check_in.manager_completed_by_teammate_id)
      if company_teammate
        check_in.update_column(:manager_completed_by_id, company_teammate.person_id)
      end
    end
    
    PositionCheckIn.where.not(finalized_by_teammate_id: nil).find_each do |check_in|
      company_teammate = CompanyTeammate.find_by(id: check_in.finalized_by_teammate_id)
      if company_teammate
        check_in.update_column(:finalized_by_id, company_teammate.person_id)
      end
    end
    
    # Remove indexes
    remove_index :position_check_ins, :manager_completed_by_teammate_id
    remove_index :position_check_ins, :finalized_by_teammate_id
    
    # Remove columns
    remove_column :position_check_ins, :manager_completed_by_teammate_id
    remove_column :position_check_ins, :finalized_by_teammate_id
  end
end
