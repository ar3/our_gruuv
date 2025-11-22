class PromptQuestion < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :prompt_template
  has_many :prompt_answers, dependent: :destroy

  # Validations
  validates :label, presence: true
  validates :position, presence: true, uniqueness: { scope: :prompt_template_id }

  # Scopes
  scope :ordered, -> { order(:position) }

  # Callbacks
  before_validation :set_position, on: :create

  private

  def set_position
    return if position.present?
    return unless prompt_template.present?
    
    max_position = prompt_template.prompt_questions.maximum(:position) || 0
    self.position = max_position + 1
  end
end

