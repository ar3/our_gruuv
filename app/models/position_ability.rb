# frozen_string_literal: true

class PositionAbility < ApplicationRecord
  # Associations
  belongs_to :position
  belongs_to :ability

  # Validations
  validates :position, presence: true
  validates :ability, presence: true
  validates :milestone_level, presence: true,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :ability_id, uniqueness: { scope: :position_id,
                                        message: 'has already been taken for this position' }

  # Custom validation for organization scoping
  validate :position_and_ability_same_organization

  # Scopes
  scope :for_position, ->(position) { where(position: position) }
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

  def position_and_ability_same_organization
    return unless position && ability

    unless ability.company_id == position.company.id
      errors.add(:ability, 'must belong to the same company as the position')
    end
  end
end
