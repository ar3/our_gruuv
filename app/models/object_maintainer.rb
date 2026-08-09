# frozen_string_literal: true

class ObjectMaintainer < ApplicationRecord
  MAINTAINABLE_TYPES = %w[Assignment Position Ability].freeze

  belongs_to :maintainable, polymorphic: true
  belongs_to :company_teammate, class_name: "CompanyTeammate"
  belongs_to :added_by, class_name: "CompanyTeammate", optional: true

  validates :maintainable_type, inclusion: { in: MAINTAINABLE_TYPES }
  validates :company_teammate_id, uniqueness: { scope: [ :maintainable_type, :maintainable_id ] }
  validate :teammate_belongs_to_maintainable_organization

  scope :for_assignments, -> { where(maintainable_type: "Assignment") }
  scope :for_positions, -> { where(maintainable_type: "Position") }
  scope :for_abilities, -> { where(maintainable_type: "Ability") }

  def self.maintained_assignment_ids_for(teammate)
    for_assignments.where(company_teammate: teammate).pluck(:maintainable_id)
  end

  private

  def teammate_belongs_to_maintainable_organization
    return if company_teammate.blank? || maintainable.blank?

    org_id = maintainable_organization_id
    return if org_id.blank?
    return if company_teammate.organization_id == org_id

    errors.add(:company_teammate, "must belong to the same organization as the maintainable object")
  end

  def maintainable_organization_id
    case maintainable
    when Assignment, Ability
      maintainable.company_id
    when Position
      maintainable.title&.company_id
    end
  end
end
