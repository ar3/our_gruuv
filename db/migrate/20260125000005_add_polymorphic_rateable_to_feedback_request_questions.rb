class AddPolymorphicRateableToFeedbackRequestQuestions < ActiveRecord::Migration[8.0]
  def change
    add_reference :feedback_request_questions, :rateable, polymorphic: true, null: true, index: true
  end
end
