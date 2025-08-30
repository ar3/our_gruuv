class AddDirectReferencesToAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def up
    # Delete all existing check-ins since we're restructuring the table
    # and there's no real production data yet
    execute "DELETE FROM assignment_check_ins"
    
    # Remove the old foreign key and column
    remove_reference :assignment_check_ins, :assignment_tenure, null: false, foreign_key: true
    
    # Add new direct references
    add_reference :assignment_check_ins, :person, null: false, foreign_key: true
    add_reference :assignment_check_ins, :assignment, null: false, foreign_key: true
    
    # Remove old indexes that are no longer needed
    remove_index :assignment_check_ins, :assignment_tenure_id, if_exists: true
    remove_index :assignment_check_ins, [:assignment_tenure_id, :check_in_started_on], if_exists: true
    
    # Add new indexes for the direct references
    add_index :assignment_check_ins, [:person_id, :check_in_started_on]
    add_index :assignment_check_ins, [:assignment_id, :check_in_started_on]
    add_index :assignment_check_ins, [:person_id, :assignment_id, :check_in_started_on]
  end

  def down
    # Remove new direct references
    remove_reference :assignment_check_ins, :person, foreign_key: true
    remove_reference :assignment_check_ins, :assignment, foreign_key: true
    
    # Remove new indexes
    remove_index :assignment_check_ins, [:person_id, :check_in_started_on], if_exists: true
    remove_index :assignment_check_ins, [:assignment_id, :check_in_started_on], if_exists: true
    remove_index :assignment_check_ins, [:person_id, :assignment_id, :check_in_started_on], if_exists: true
    
    # Add back the old reference
    add_reference :assignment_check_ins, :assignment_tenure, null: false, foreign_key: true
    
    # Add back old indexes
    add_index :assignment_check_ins, :assignment_tenure_id
    add_index :assignment_check_ins, [:assignment_tenure_id, :check_in_started_on]
  end
end
