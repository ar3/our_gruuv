class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :prompt_template, null: false, foreign_key: true
      t.datetime :closed_at

      t.timestamps
    end

    add_index :prompts, [:company_teammate_id, :prompt_template_id]
    # Partial unique index: only one open prompt per teammate
    add_index :prompts, :company_teammate_id, 
              unique: true, 
              where: "closed_at IS NULL",
              name: "index_prompts_on_company_teammate_id_when_open"
  end
end
