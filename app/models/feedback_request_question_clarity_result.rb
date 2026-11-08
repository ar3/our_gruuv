# frozen_string_literal: true

class FeedbackRequestQuestionClarityResult < ApplicationRecord
  belongs_to :og_consultation

  def suggestions
    Array((payload || {}).stringify_keys['suggestions'])
  end

  def summary
    (payload || {}).stringify_keys['summary'].to_s
  end

  def suggestion_for_question(question_id)
    suggestions.find { |row| row.stringify_keys['feedback_request_question_id'].to_i == question_id.to_i }
  end
end
