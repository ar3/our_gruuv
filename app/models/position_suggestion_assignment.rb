# frozen_string_literal: true

class PositionSuggestionAssignment < ApplicationRecord
  has_paper_trail

  belongs_to :position_suggestion
  belongs_to :source_assignment, class_name: "Assignment"
  belongs_to :last_modified_by, class_name: "CompanyTeammate"

  has_many :outcomes,
           class_name: "PositionSuggestionAssignmentOutcome",
           dependent: :destroy,
           inverse_of: :position_suggestion_assignment

  validates :title, presence: true
  validates :source_assignment_id, uniqueness: { scope: :position_suggestion_id }
  validate :source_assignment_on_position

  def outcomes_fingerprint
    outcomes.order(:position, :id).map do |outcome|
      [
        outcome.description.to_s,
        outcome.outcome_type.to_s,
        outcome.progress_report_url.to_s,
        outcome.management_relationship_filter.to_s,
        outcome.team_relationship_filter.to_s,
        outcome.consumer_assignment_filter.to_s
      ]
    end
  end

  def field_snapshot
    {
      "title" => title.to_s,
      "tagline" => normalize_text(tagline),
      "required_activities" => normalize_text(required_activities),
      "handbook" => normalize_text(handbook),
      "outcomes" => outcomes_fingerprint
    }
  end

  private

  def normalize_text(value)
    str = value.to_s
    str.strip.empty? ? nil : str
  end

  def source_assignment_on_position
    return unless position_suggestion && source_assignment

    return if position_suggestion.suggestable_assignment?(source_assignment)

    errors.add(:source_assignment, "must be on this position or proposed via an add link")
  end
end
