class AssignmentAbility < ApplicationRecord
  # Associations
  belongs_to :assignment
  belongs_to :ability

  # Validations
  validates :assignment, presence: true
  validates :ability, presence: true
  validates :milestone_level, presence: true, 
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :ability_id, uniqueness: { scope: :assignment_id, 
                                      message: 'has already been taken for this assignment' }

  # Custom validation for organization scoping
  validate :assignment_and_ability_same_organization

  # Scopes
  scope :for_assignment, ->(assignment) { where(assignment: assignment) }
  scope :for_ability, ->(ability) { where(ability: ability) }
  scope :by_milestone_level, -> { order(:milestone_level) }

  # Instance methods
  def milestone_level_display
    "Milestone #{milestone_level}"
  end

  def requirement_display
    "#{ability.name} - #{milestone_level_display}"
  end

  private

  def assignment_and_ability_same_organization
    return unless assignment && ability

    # Check if ability's organization is in assignment's company hierarchy
    company_hierarchy = assignment.company.self_and_descendants.map(&:id)
    # OR check if assignment's company is in ability's organization hierarchy
    ability_org_hierarchy = ability.organization.self_and_descendants.map(&:id)
    
    unless company_hierarchy.include?(ability.organization_id) || 
           ability_org_hierarchy.include?(assignment.company_id)
      errors.add(:ability, 'must belong to the same organization hierarchy as the assignment')
    end
  end
end
