# frozen_string_literal: true

class AssignmentFlowMembership < ApplicationRecord
  # Associations
  belongs_to :assignment_flow
  belongs_to :assignment
  belongs_to :added_by, class_name: 'CompanyTeammate'

  # Validations
  validates :assignment_flow, presence: true
  validates :assignment, presence: true
  validates :placement, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :added_by, presence: true
  validates :assignment_id, uniqueness: { scope: :assignment_flow_id }
  validate :assignment_belongs_to_flow_company

  private

  def assignment_belongs_to_flow_company
    return unless assignment_flow && assignment
    return if assignment.company_id == assignment_flow.company_id

    errors.add(:assignment, 'must belong to the same company as the assignment flow')
  end
end
