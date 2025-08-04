class PositionAssignment < ApplicationRecord
  # Associations
  belongs_to :position
  belongs_to :assignment
  
  # Validations
  validates :position, presence: true
  validates :assignment, presence: true
  validates :assignment_type, presence: true, inclusion: { in: %w[required suggested] }
  validates :assignment, uniqueness: { scope: :position }
  validates :min_estimated_energy, numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :max_estimated_energy, numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }
  validate :max_energy_greater_than_min_energy, if: -> { min_estimated_energy.present? && max_estimated_energy.present? }
  
  # Scopes
  scope :required, -> { where(assignment_type: 'required') }
  scope :suggested, -> { where(assignment_type: 'suggested') }
  
  # Instance methods
  def display_name
    "#{assignment.title} (#{assignment_type})"
  end

  def energy_range_display
    if min_estimated_energy.present? && max_estimated_energy.present?
      "#{min_estimated_energy}%-#{max_estimated_energy}% of effort"
    elsif min_estimated_energy.present?
      "#{min_estimated_energy}%+ of effort"
    elsif max_estimated_energy.present?
      "Up to #{max_estimated_energy}% of effort"
    else
      "No effort estimate"
    end
  end

  private

  def max_energy_greater_than_min_energy
    if max_estimated_energy < min_estimated_energy
      errors.add(:max_estimated_energy, "must be greater than minimum energy")
    end
  end
end 