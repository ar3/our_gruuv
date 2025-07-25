class RenameHuddlePlaybookIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the old index
    remove_index :huddle_playbooks, name: "index_huddle_instructions_on_org_and_instruction_alias"
    
    # Add the new index with the correct name
    add_index :huddle_playbooks, [:organization_id, :special_session_name], 
              unique: true, 
              name: "index_huddle_playbooks_on_org_and_special_session_name"
  end
end
