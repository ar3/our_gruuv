class FeedbackRequestQuestion < ApplicationRecord
  belongs_to :feedback_request
  belongs_to :rateable, polymorphic: true, optional: true
  has_many :observations, dependent: :nullify

  # Validations (question_text may be blank when created in select_focus; filled in feedback_prompt)
  validates :position, presence: true, uniqueness: { scope: :feedback_request_id }
  validate :rateable_must_be_valid_type

  # Scopes
  scope :ordered, -> { order(:position) }

  # For the feedback_prompt step: show question_text if set, else default by rateable type:
  # - Assignment with sentiment outcomes: those outcomes separated by double newlines.
  # - Assignment with no sentiment outcomes: "When I think about my recent experience of <casual name> being a <assignment>..."
  # - Ability or Aspiration: "When I think about my recent experience of <casual name> demonstrating <name>..."
  def prompt_default_text
    return question_text if question_text.present?
    return '' unless rateable.present?

    subject_name = feedback_request.subject_of_feedback_teammate&.person&.casual_name.presence || 'the subject'

    case rateable_type
    when 'Assignment'
      sentiment_descriptions = rateable.assignment_outcomes
        .where(outcome_type: 'sentiment')
        .order(:created_at)
        .pluck(:description)
      return sentiment_descriptions.join("\n\n") if sentiment_descriptions.any?
      assignment_name = rateable.title.presence || 'this assignment'
      "When I think about my recent experience of #{subject_name} being a #{assignment_name}..."
    when 'Ability', 'Aspiration'
      item_name = rateable.name.presence || 'this'
      "When I think about my recent experience of #{subject_name} demonstrating #{item_name}..."
    else
      ''
    end
  end

  private

  def rateable_must_be_valid_type
    return if rateable_type.blank? # Optional
    unless ['Assignment', 'Ability', 'Aspiration', 'Position'].include?(rateable_type)
      errors.add(:rateable_type, 'must be Assignment, Ability, Aspiration, or Position')
    end
  end
end
