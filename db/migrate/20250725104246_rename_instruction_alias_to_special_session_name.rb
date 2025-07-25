class RenameInstructionAliasToSpecialSessionName < ActiveRecord::Migration[8.0]
  def change
    rename_column :huddle_playbooks, :instruction_alias, :special_session_name
  end
end
