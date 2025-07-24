class RenameHuddleInstructionsToHuddlePlaybooks < ActiveRecord::Migration[7.1]
  def change
    # Rename the table
    rename_table :huddle_instructions, :huddle_playbooks
    
    # Update the foreign key column name
    rename_column :huddles, :huddle_instruction_id, :huddle_playbook_id
  end
end
