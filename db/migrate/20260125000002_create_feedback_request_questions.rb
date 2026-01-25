class CreateFeedbackRequestQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_request_questions do |t|
      t.references :feedback_request, null: false, foreign_key: true
      t.text :question_text, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :feedback_request_questions, :feedback_request_id, if_not_exists: true
    add_index :feedback_request_questions, :position, if_not_exists: true
    add_index :feedback_request_questions, [:feedback_request_id, :position], unique: true, name: 'index_feedback_request_questions_on_request_and_position'
  end
end
