class ConvertMaapSnapshotPersonToCompanyTeammate < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraints that will prevent updating the columns
    # Find and remove employee_id foreign key
    employee_fk = ActiveRecord::Base.connection.foreign_keys('maap_snapshots').find { |fk| fk.column == 'employee_id' }
    if employee_fk && foreign_key_exists?(:maap_snapshots, :people, column: :employee_id, name: employee_fk.name)
      remove_foreign_key :maap_snapshots, :people, column: :employee_id, name: employee_fk.name
    end
    
    # Find and remove created_by_id foreign key
    created_by_fk = ActiveRecord::Base.connection.foreign_keys('maap_snapshots').find { |fk| fk.column == 'created_by_id' }
    if created_by_fk && foreign_key_exists?(:maap_snapshots, :people, column: :created_by_id, name: created_by_fk.name)
      remove_foreign_key :maap_snapshots, :people, column: :created_by_id, name: created_by_fk.name
    end
    
    # Add new columns
    add_column :maap_snapshots, :employee_company_teammate_id, :bigint
    add_column :maap_snapshots, :creator_company_teammate_id, :bigint
    
    # Add indexes
    add_index :maap_snapshots, :employee_company_teammate_id
    add_index :maap_snapshots, :creator_company_teammate_id
    
    # Add foreign key constraints
    add_foreign_key :maap_snapshots, :teammates, column: :employee_company_teammate_id
    add_foreign_key :maap_snapshots, :teammates, column: :creator_company_teammate_id
    
    # Migrate employee_id to employee_company_teammate_id
    employee_migrated = 0
    employee_orphaned = 0
    
    MaapSnapshot.where.not(employee_id: nil).find_each do |snapshot|
      person_id = snapshot.employee_id
      company_id = snapshot.company_id
      
      # Skip if no company_id
      unless company_id
        Rails.logger.warn("MaapSnapshot id=#{snapshot.id} has no company_id, skipping employee migration")
        next
      end
      
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        snapshot.update_columns(
          employee_company_teammate_id: company_teammate.id,
          employee_id: -1 * snapshot.employee_id
        )
        employee_migrated += 1
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for maap_snapshot_id=#{snapshot.id}")
        # Still invalidate the old field
        snapshot.update_column(:employee_id, -1 * snapshot.employee_id)
        employee_orphaned += 1
      end
    end
    
    # Migrate created_by_id to creator_company_teammate_id
    creator_migrated = 0
    creator_orphaned = 0
    
    MaapSnapshot.where.not(created_by_id: nil).find_each do |snapshot|
      person_id = snapshot.created_by_id
      # Skip if already negative (from employee migration above)
      next if person_id < 0
      
      company_id = snapshot.company_id
      
      # Skip if no company_id
      unless company_id
        Rails.logger.warn("MaapSnapshot id=#{snapshot.id} has no company_id, skipping creator migration")
        next
      end
      
      company_teammate = CompanyTeammate.find_by(person_id: person_id, organization_id: company_id)
      
      if company_teammate
        snapshot.update_columns(
          creator_company_teammate_id: company_teammate.id,
          created_by_id: -1 * snapshot.created_by_id
        )
        creator_migrated += 1
      else
        # Log warning - teammate not found
        Rails.logger.warn("Could not find CompanyTeammate for person_id=#{person_id}, company_id=#{company_id} for maap_snapshot_id=#{snapshot.id}")
        # Still invalidate the old field
        snapshot.update_column(:created_by_id, -1 * snapshot.created_by_id)
        creator_orphaned += 1
      end
    end
    
    # Log summary
    Rails.logger.info("MaapSnapshot migration summary:")
    Rails.logger.info("  Employee: #{employee_migrated} migrated, #{employee_orphaned} orphaned")
    Rails.logger.info("  Creator: #{creator_migrated} migrated, #{creator_orphaned} orphaned")
    puts "\nMaapSnapshot migration summary:"
    puts "  Employee: #{employee_migrated} migrated, #{employee_orphaned} orphaned"
    puts "  Creator: #{creator_migrated} migrated, #{creator_orphaned} orphaned"
  end
  
  def down
    raise ActiveRecord::IrreversibleMigration, "This migration cannot be reversed"
  end
end
