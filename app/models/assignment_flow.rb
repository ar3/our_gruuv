# frozen_string_literal: true

class AssignmentFlow < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  belongs_to :created_by, class_name: 'CompanyTeammate'
  belongs_to :updated_by, class_name: 'CompanyTeammate'
  has_many :assignment_flow_memberships, dependent: :destroy
  has_many :assignments, through: :assignment_flow_memberships

  # Validations
  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :company, presence: true
  validates :created_by, presence: true
  validates :updated_by, presence: true

  # Alias for policy/organization context
  def organization
    company
  end

  # Ordered memberships by placement, then group name, then assignment title
  def ordered_memberships
    assignment_flow_memberships
      .includes(assignment: [:department, :assignment_outcomes])
      .joins(:assignment)
      .order(:placement, :group_name, 'assignments.title')
  end
end
