class UpdatePromptsUniqueIndexToIncludeTemplate < ActiveRecord::Migration[8.0]
  def change
    # Remove the old unique index that only checked company_teammate_id
    remove_index :prompts, 
                 name: "index_prompts_on_company_teammate_id_when_open"
    
    # Add new unique index that includes both company_teammate_id and prompt_template_id
    # This allows multiple open prompts per teammate, but only one per template
    add_index :prompts, 
              [:company_teammate_id, :prompt_template_id], 
              unique: true, 
              where: "closed_at IS NULL",
              name: "index_prompts_on_teammate_and_template_when_open"
  end
end
