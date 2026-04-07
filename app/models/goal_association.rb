class GoalAssociation < ApplicationRecord
  ASSOCIABLE_TYPES = %w[Assignment Ability Aspiration].freeze

  belongs_to :goal
  belongs_to :associable, polymorphic: true

  validates :goal, presence: true
  validates :associable, presence: true
  validates :associable_type, inclusion: { in: ASSOCIABLE_TYPES }
  validates :goal_id, uniqueness: { scope: [:associable_type, :associable_id] }
  validate :goal_company_matches_associable_company

  private

  def goal_company_matches_associable_company
    return unless goal && associable
    return unless associable.respond_to?(:company_id)

    if goal.company_id != associable.company_id
      errors.add(:goal, 'must belong to the same company as the associated record')
    end
  end
end
