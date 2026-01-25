class AddFeedbackRequestQuestionToObservations < ActiveRecord::Migration[8.0]
  def change
    add_reference :observations, :feedback_request_question, null: true, foreign_key: true
    add_index :observations, :feedback_request_question_id, if_not_exists: true
  end
end
