# frozen_string_literal: true

class TeamPrimaryOutcome < ApplicationRecord
  belongs_to :team
  belongs_to :assignment_outcome

  validates :assignment_outcome_id, uniqueness: { scope: :team_id }
  validate :outcome_belongs_to_needed_assignment

  scope :ordered, lambda {
    joins(assignment_outcome: :assignment)
      .order("assignments.title ASC, assignment_outcomes.created_at ASC")
  }

  private

  def outcome_belongs_to_needed_assignment
    return if team.blank? || assignment_outcome.blank?

    assignment = assignment_outcome.assignment
    unless team.team_assignment_needs.exists?(assignment_id: assignment.id)
      errors.add(:assignment_outcome, "must belong to an assignment needed by the team")
      return
    end

    return if assignment.company_id == team.company_id

    errors.add(:assignment_outcome, "must belong to the same company as the team")
  end
end
