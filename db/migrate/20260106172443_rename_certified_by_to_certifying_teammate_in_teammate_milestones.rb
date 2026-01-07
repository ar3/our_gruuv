class RenameCertifiedByToCertifyingTeammateInTeammateMilestones < ActiveRecord::Migration[8.0]
  def up
    # Add new column (nullable initially)
    add_column :teammate_milestones, :certifying_teammate_id, :bigint
    add_index :teammate_milestones, :certifying_teammate_id, name: 'index_teammate_milestones_on_certifying_teammate_id'
    
    # Migrate data: For each milestone, find the CompanyTeammate for the certified_by person
    # in the milestone's teammate's organization
    execute <<-SQL
      UPDATE teammate_milestones
      SET certifying_teammate_id = (
        SELECT teammates.id
        FROM teammates
        WHERE teammates.person_id = teammate_milestones.certified_by_id
          AND teammates.organization_id = (
            SELECT teammates.organization_id
            FROM teammates
            WHERE teammates.id = teammate_milestones.teammate_id
          )
          AND teammates.type = 'CompanyTeammate'
        LIMIT 1
      )
    SQL
    
    # Handle edge cases - log any that couldn't be migrated
    # For now, we'll set them to NULL and handle in a follow-up if needed
    # In production, you might want to create CompanyTeammate records or handle differently
    
    # Make the column non-nullable
    change_column_null :teammate_milestones, :certifying_teammate_id, false
    
    # Add foreign key constraint
    add_foreign_key :teammate_milestones, :teammates, column: :certifying_teammate_id
    
    # Remove old column and index
    remove_foreign_key :teammate_milestones, :people, column: :certified_by_id if foreign_key_exists?(:teammate_milestones, :people, column: :certified_by_id)
    remove_index :teammate_milestones, name: 'index_teammate_milestones_on_certified_by_id' if index_exists?(:teammate_milestones, :certified_by_id)
    remove_column :teammate_milestones, :certified_by_id
  end
  
  def down
    # Add back the old column
    add_column :teammate_milestones, :certified_by_id, :bigint
    add_index :teammate_milestones, :certified_by_id, name: 'index_teammate_milestones_on_certified_by_id'
    
    # Migrate data back
    execute <<-SQL
      UPDATE teammate_milestones
      SET certified_by_id = (
        SELECT teammates.person_id
        FROM teammates
        WHERE teammates.id = teammate_milestones.certifying_teammate_id
        LIMIT 1
      )
    SQL
    
    # Make non-nullable
    change_column_null :teammate_milestones, :certified_by_id, false
    
    # Add foreign key
    add_foreign_key :teammate_milestones, :people, column: :certified_by_id
    
    # Remove new column
    remove_foreign_key :teammate_milestones, :teammates, column: :certifying_teammate_id if foreign_key_exists?(:teammate_milestones, :teammates, column: :certifying_teammate_id)
    remove_index :teammate_milestones, name: 'index_teammate_milestones_on_certifying_teammate_id' if index_exists?(:teammate_milestones, :certifying_teammate_id)
    remove_column :teammate_milestones, :certifying_teammate_id
  end
end
