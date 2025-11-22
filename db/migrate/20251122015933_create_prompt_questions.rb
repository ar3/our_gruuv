class CreatePromptQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_questions do |t|
      t.references :prompt_template, null: false, foreign_key: true
      t.string :label, null: false
      t.text :placeholder_text
      t.text :helper_text
      t.integer :position, null: false

      t.timestamps
    end

    add_index :prompt_questions, [:prompt_template_id, :position], unique: true
  end
end
