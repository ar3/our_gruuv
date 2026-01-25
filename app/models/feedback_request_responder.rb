class FeedbackRequestResponder < ApplicationRecord
  belongs_to :feedback_request
  belongs_to :teammate

  # Validations
  validates :feedback_request_id, uniqueness: { scope: :teammate_id }
end
