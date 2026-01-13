class AssignmentSupplyRelationship < ApplicationRecord
  # Associations
  belongs_to :supplier_assignment, class_name: 'Assignment'
  belongs_to :consumer_assignment, class_name: 'Assignment'

  # Validations
  validates :supplier_assignment, presence: true
  validates :consumer_assignment, presence: true
  validates :supplier_assignment_id, uniqueness: { scope: :consumer_assignment_id }
  validate :assignments_same_company_hierarchy
  validate :not_self_referential

  private

  def assignments_same_company_hierarchy
    return unless supplier_assignment && consumer_assignment

    supplier_company = supplier_assignment.company
    consumer_company = consumer_assignment.company

    # Check if both assignments belong to the same company hierarchy
    supplier_hierarchy = supplier_company.self_and_descendants.map(&:id)
    consumer_hierarchy = consumer_company.self_and_descendants.map(&:id)

    unless supplier_hierarchy.include?(consumer_company.id) || consumer_hierarchy.include?(supplier_company.id)
      errors.add(:base, 'Both assignments must belong to the same company hierarchy')
    end
  end

  def not_self_referential
    return unless supplier_assignment && consumer_assignment

    if supplier_assignment_id == consumer_assignment_id
      errors.add(:base, 'An assignment cannot be both supplier and consumer of itself')
    end
  end
end
