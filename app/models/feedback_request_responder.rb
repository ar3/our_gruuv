class FeedbackRequestResponder < ApplicationRecord
  belongs_to :feedback_request
  belongs_to :company_teammate, class_name: 'CompanyTeammate', foreign_key: 'teammate_id'
  alias_method :teammate, :company_teammate
  alias_method :teammate=, :company_teammate=

  # Validations
  validates :feedback_request_id, uniqueness: { scope: :teammate_id }
end
