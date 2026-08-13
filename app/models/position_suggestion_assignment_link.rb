# frozen_string_literal: true

class PositionSuggestionAssignmentLink < ApplicationRecord
  has_paper_trail

  ACTIONS = %w[add update remove].freeze
  ASSIGNMENT_TYPES = %w[required suggested].freeze

  belongs_to :position_suggestion
  belongs_to :assignment
  belongs_to :last_modified_by, class_name: "CompanyTeammate"

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :assignment_type, presence: true, inclusion: { in: ASSIGNMENT_TYPES }
  validates :assignment_id, uniqueness: { scope: :position_suggestion_id }
  validates :min_estimated_energy,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :max_estimated_energy,
            numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }
  validate :max_energy_greater_than_min_energy,
           if: -> { min_estimated_energy.present? && max_estimated_energy.present? }
  validate :assignment_in_same_company
  validate :action_matches_live_edge

  scope :adds, -> { where(action: "add") }
  scope :updates, -> { where(action: "update") }
  scope :removes, -> { where(action: "remove") }

  def add?
    action == "add"
  end

  def update_action?
    action == "update"
  end

  def remove?
    action == "remove"
  end

  def edge_snapshot
    {
      "action" => action.to_s,
      "assignment_type" => assignment_type.to_s,
      "min_estimated_energy" => min_estimated_energy,
      "max_estimated_energy" => max_estimated_energy
    }
  end

  def energy_range_display
    if min_estimated_energy.present? && max_estimated_energy.present?
      "#{min_estimated_energy}%-#{max_estimated_energy}% of energy"
    elsif min_estimated_energy.present?
      "#{min_estimated_energy}%+ of energy"
    elsif max_estimated_energy.present?
      "Up to #{max_estimated_energy}% of energy"
    else
      "No effort estimate"
    end
  end

  private

  def max_energy_greater_than_min_energy
    return if max_estimated_energy >= min_estimated_energy

    errors.add(:max_estimated_energy, "must be greater than minimum energy")
  end

  def assignment_in_same_company
    return unless position_suggestion && assignment

    company_id = position_suggestion.organization.root_company&.id || position_suggestion.organization_id
    return if assignment.company_id == company_id

    errors.add(:assignment, "must belong to the same organization")
  end

  def action_matches_live_edge
    return unless position_suggestion && assignment && action.present?

    on_position = position_suggestion.position.assignments.exists?(id: assignment_id)
    case action
    when "add"
      errors.add(:action, "can only add Assignments not already on this Position") if on_position
    when "update", "remove"
      errors.add(:action, "requires the Assignment to already be on this Position") unless on_position
    end
  end
end
