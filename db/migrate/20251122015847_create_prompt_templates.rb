class CreatePromptTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_templates do |t|
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.string :title, null: false
      t.text :description
      t.date :available_at
      t.boolean :is_primary, default: false, null: false
      t.boolean :is_secondary, default: false, null: false
      t.boolean :is_tertiary, default: false, null: false

      t.timestamps
    end

    add_index :prompt_templates, :available_at
    add_index :prompt_templates, [:company_id, :is_primary], where: "is_primary = true"
    add_index :prompt_templates, [:company_id, :is_secondary], where: "is_secondary = true"
    add_index :prompt_templates, [:company_id, :is_tertiary], where: "is_tertiary = true"
  end
end
