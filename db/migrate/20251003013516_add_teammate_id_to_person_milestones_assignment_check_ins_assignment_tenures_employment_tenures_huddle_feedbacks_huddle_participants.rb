class AddTeammateIdToPersonMilestonesAssignmentCheckInsAssignmentTenuresEmploymentTenuresHuddleFeedbacksHuddleParticipants < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:person_organization_accesses) && !table_exists?(:teammates)
      rename_table :person_organization_accesses, :teammates
    end
    
    # Add teammate_id to person_milestones
    add_reference :person_milestones, :teammate, null: true, foreign_key: true
    # Check if index exists before adding
    add_index :person_milestones, :teammate_id unless index_exists?(:person_milestones, :teammate_id)
    
    # Add teammate_id to assignment_check_ins
    add_reference :assignment_check_ins, :teammate, null: true, foreign_key: true
    add_index :assignment_check_ins, :teammate_id unless index_exists?(:assignment_check_ins, :teammate_id)
    
    # Add teammate_id to assignment_tenures
    add_reference :assignment_tenures, :teammate, null: true, foreign_key: true
    add_index :assignment_tenures, :teammate_id unless index_exists?(:assignment_tenures, :teammate_id)
    
    # Add teammate_id to employment_tenures
    add_reference :employment_tenures, :teammate, null: true, foreign_key: true
    add_index :employment_tenures, :teammate_id unless index_exists?(:employment_tenures, :teammate_id)
    
    # Add teammate_id to huddle_feedbacks
    add_reference :huddle_feedbacks, :teammate, null: true, foreign_key: true
    add_index :huddle_feedbacks, :teammate_id unless index_exists?(:huddle_feedbacks, :teammate_id)
    
    # Add teammate_id to huddle_participants
    add_reference :huddle_participants, :teammate, null: true, foreign_key: true
    add_index :huddle_participants, :teammate_id unless index_exists?(:huddle_participants, :teammate_id)
  end

  def down
    # Remove teammate_id from huddle_participants
    remove_index :huddle_participants, :teammate_id
    remove_reference :huddle_participants, :teammate, foreign_key: true
    
    # Remove teammate_id from huddle_feedbacks
    remove_index :huddle_feedbacks, :teammate_id
    remove_reference :huddle_feedbacks, :teammate, foreign_key: true
    
    # Remove teammate_id from employment_tenures
    remove_index :employment_tenures, :teammate_id
    remove_reference :employment_tenures, :teammate, foreign_key: true
    
    # Remove teammate_id from assignment_tenures
    remove_index :assignment_tenures, :teammate_id
    remove_reference :assignment_tenures, :teammate, foreign_key: true
    
    # Remove teammate_id from assignment_check_ins
    remove_index :assignment_check_ins, :teammate_id
    remove_reference :assignment_check_ins, :teammate, foreign_key: true
    
    # Remove teammate_id from person_milestones
    remove_index :person_milestones, :teammate_id
    remove_reference :person_milestones, :teammate, foreign_key: true
  end
end
