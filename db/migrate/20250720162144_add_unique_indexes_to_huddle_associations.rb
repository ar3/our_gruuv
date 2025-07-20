class AddUniqueIndexesToHuddleAssociations < ActiveRecord::Migration[8.0]
  def change
    # Add unique index for huddle_participants to prevent duplicate person-huddle associations
    add_index :huddle_participants, [:huddle_id, :person_id], unique: true, name: 'index_huddle_participants_on_huddle_and_person_unique'
    
    # Add unique index for huddle_feedbacks to prevent duplicate feedback submissions
    add_index :huddle_feedbacks, [:huddle_id, :person_id], unique: true, name: 'index_huddle_feedbacks_on_huddle_and_person_unique'
  end
end
