class AddCanManagePromptsToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :can_manage_prompts, :boolean
    add_index :teammates, :can_manage_prompts
  end
end
