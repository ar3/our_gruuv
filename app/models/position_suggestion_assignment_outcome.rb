# frozen_string_literal: true

class PositionSuggestionAssignmentOutcome < ApplicationRecord
  belongs_to :position_suggestion_assignment, inverse_of: :outcomes

  validates :description, presence: true
  validates :outcome_type, presence: true, inclusion: { in: AssignmentOutcome::TYPES }
  validates :management_relationship_filter,
            inclusion: { in: %w[direct_employee direct_manager no_relationship], allow_blank: true }
  validates :team_relationship_filter,
            inclusion: { in: %w[same_team different_team], allow_blank: true }
  validates :consumer_assignment_filter,
            inclusion: { in: %w[active_consumer not_consumer], allow_blank: true }
end
