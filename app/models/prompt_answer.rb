class PromptAnswer < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :prompt
  belongs_to :prompt_question
  belongs_to :updated_by_company_teammate, class_name: 'CompanyTeammate', optional: true

  # Scopes
  scope :with_content, -> { where("LENGTH(TRIM(COALESCE(prompt_answers.text, ''))) > 10") }

  # Validations
  validates :prompt, presence: true
  validates :prompt_question, presence: true
  validates :prompt_question_id, uniqueness: { scope: :prompt_id }

  # Note: updated_by_company_teammate_id should be set by the controller when updating
end

