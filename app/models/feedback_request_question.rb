class FeedbackRequestQuestion < ApplicationRecord
  belongs_to :feedback_request
  belongs_to :rateable, polymorphic: true, optional: true
  has_many :observations, dependent: :nullify

  # Validations
  validates :question_text, presence: true
  validates :position, presence: true, uniqueness: { scope: :feedback_request_id }
  validate :rateable_must_be_valid_type

  # Scopes
  scope :ordered, -> { order(:position) }

  private

  def rateable_must_be_valid_type
    return if rateable_type.blank? # Optional
    unless ['Assignment', 'Ability', 'Aspiration', 'Position'].include?(rateable_type)
      errors.add(:rateable_type, 'must be Assignment, Ability, Aspiration, or Position')
    end
  end
end
