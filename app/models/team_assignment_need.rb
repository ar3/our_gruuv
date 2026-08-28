# frozen_string_literal: true

class TeamAssignmentNeed < ApplicationRecord
  NEED_TYPES = %w[required nice_to_have].freeze

  belongs_to :team
  belongs_to :assignment
  has_many :team_assignment_coverers, dependent: :destroy
  has_many :company_teammates, through: :team_assignment_coverers

  validates :need_type, presence: true, inclusion: { in: NEED_TYPES }
  validates :assignment_id, uniqueness: { scope: :team_id }
  validate :assignment_belongs_to_team_company

  scope :required, -> { where(need_type: "required") }
  scope :nice_to_have, -> { where(need_type: "nice_to_have") }
  scope :ordered_by_assignment_title, -> { joins(:assignment).order("assignments.title ASC") }

  def required?
    need_type == "required"
  end

  def nice_to_have?
    need_type == "nice_to_have"
  end

  private

  def assignment_belongs_to_team_company
    return if team.blank? || assignment.blank?
    return if assignment.company_id == team.company_id

    errors.add(:assignment, "must belong to the same company as the team")
  end
end
