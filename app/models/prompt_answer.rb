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

  # Keep prompt's updated_at in sync when answers are created or changed
  after_save :touch_prompt

  # Note: updated_by_company_teammate_id should be set by the controller when updating

  private

  def touch_prompt
    prompt.touch
  end
end

