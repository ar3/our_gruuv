class CreatePromptAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_answers do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :prompt_question, null: false, foreign_key: true
      t.text :text
      t.references :updated_by_company_teammate, null: true, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :prompt_answers, [:prompt_id, :prompt_question_id], unique: true
  end
end
