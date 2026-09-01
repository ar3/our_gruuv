# frozen_string_literal: true

class PositionSuggestionMilestone < ApplicationRecord
  has_paper_trail

  # Phase 1: AssignmentAbility. Later: PositionAbility, Ability ("direct" milestone associations).
  MILESTONEABLE_TYPES = %w[AssignmentAbility PositionAbility Ability].freeze

  DECISIONS = %w[accepted rejected].freeze

  belongs_to :position_suggestion
  belongs_to :milestoneable, polymorphic: true
  belongs_to :last_modified_by, class_name: "CompanyTeammate"
  belongs_to :processed_by, class_name: "CompanyTeammate", optional: true

  validates :suggested_milestone_level,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :milestoneable_type, inclusion: { in: MILESTONEABLE_TYPES }
  validates :milestoneable_id, uniqueness: { scope: [:position_suggestion_id, :milestoneable_type] }
  validates :decision, inclusion: { in: DECISIONS }, allow_nil: true
  validate :milestoneable_in_same_company

  scope :pending_decision, -> { where(decision: nil) }
  scope :processed, -> { where.not(decision: nil) }

  def processed?
    decision.present?
  end

  def accepted?
    decision == "accepted"
  end

  def rejected?
    decision == "rejected"
  end

  def clear_decision!
    update!(decision: nil, processed_by: nil, processed_at: nil)
  end

  def current_required_level
    return milestoneable.milestone_level if milestoneable.respond_to?(:milestone_level)

    nil
  end

  def display_name
    case milestoneable
    when AssignmentAbility
      milestoneable.requirement_display
    when PositionAbility
      milestoneable.requirement_display
    when Ability
      milestoneable.name
    else
      milestoneable.to_s
    end
  end

  private

  def milestoneable_in_same_company
    return unless position_suggestion && milestoneable

    company_id = position_suggestion.organization.root_company&.id || position_suggestion.organization_id
    milestoneable_company_id =
      case milestoneable
      when AssignmentAbility
        milestoneable.assignment&.company_id
      when PositionAbility
        milestoneable.position&.title&.company_id
      when Ability
        milestoneable.company_id
      end

    return if milestoneable_company_id == company_id

    errors.add(:milestoneable, "must belong to the same organization")
  end
end
