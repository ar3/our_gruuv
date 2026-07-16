class AssignmentSurveyResponse < ApplicationRecord
  SOURCES = %w[active required active_and_required].freeze
  RATING_RANGE = (1..6).freeze

  belongs_to :submission,
             class_name: "AssignmentSurveySubmission",
             foreign_key: :assignment_survey_submission_id,
             inverse_of: :responses
  belongs_to :assignment

  validates :assignment, uniqueness: { scope: :assignment_survey_submission_id }
  validates :assignment_source, inclusion: { in: SOURCES }
  validates :snapshot_title, presence: true
  validates :understandable_rating, :possible_rating, :relevant_rating,
            inclusion: { in: RATING_RANGE },
            allow_nil: true
  validate :finalized_submission_is_immutable, on: :update

  def complete?
    understandable_rating.present? && possible_rating.present? && relevant_rating.present?
  end

  def incomplete?
    !complete?
  end

  def source_label
    {
      "active" => "Actively held",
      "required" => "Required by position",
      "active_and_required" => "Actively held + required by position"
    }.fetch(assignment_source)
  end

  private

  def finalized_submission_is_immutable
    return unless AssignmentSurveySubmission.where(id: assignment_survey_submission_id, status: "finalized").exists?

    errors.add(:base, "Finalized survey responses cannot be changed")
  end
end
