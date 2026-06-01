class PositionAssignment < ApplicationRecord
  # Associations
  belongs_to :position
  belongs_to :assignment
  
  # Validations
  validates :position, presence: true
  validates :assignment, presence: true
  validates :assignment_type, presence: true, inclusion: { in: %w[required suggested] }
  validates :assignment, uniqueness: { scope: :position }
  validates :min_estimated_energy, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :max_estimated_energy, numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }
  validate :max_energy_greater_than_min_energy, if: -> { min_estimated_energy.present? && max_estimated_energy.present? }
  
  # Scopes
  scope :required, -> { where(assignment_type: 'required') }
  scope :suggested, -> { where(assignment_type: 'suggested') }
  scope :ordered_by_max_energy_then_title, lambda {
    joins(:assignment).order(
      Arel.sql('position_assignments.max_estimated_energy DESC NULLS LAST'),
      'assignments.title ASC'
    )
  }
  
  # Instance methods
  def display_name
    "#{assignment.title} (#{assignment_type})"
  end

  def energy_range_display
    if min_estimated_energy.present? && max_estimated_energy.present?
      "#{min_estimated_energy}%-#{max_estimated_energy}% of energy"
    elsif min_estimated_energy.present?
      "#{min_estimated_energy}%+ of energy"
    elsif max_estimated_energy.present?
      "Up to #{max_estimated_energy}% of energy"
    else
      "No effort estimate"
    end
  end

  def anticipated_energy_percentage
    if min_estimated_energy.present? && max_estimated_energy.present?
      ((min_estimated_energy + max_estimated_energy) / 2.0).round
    elsif min_estimated_energy.present?
      min_estimated_energy
    elsif max_estimated_energy.present?
      max_estimated_energy
    else
      nil
    end
  end

  def energy_percentage_suffix
    if min_estimated_energy.present? && max_estimated_energy.present?
      "(#{min_estimated_energy}%-#{max_estimated_energy}%)"
    elsif min_estimated_energy.present?
      "(#{min_estimated_energy}%+)"
    elsif max_estimated_energy.present?
      "(up to #{max_estimated_energy}%)"
    else
      "(??%)"
    end
  end

  def required?
    assignment_type == 'required'
  end

  def suggested?
    assignment_type == 'suggested'
  end

  # Phrase for "usually allocate {phrase} of their overall energy" on assignment check-in pages.
  def blueprint_energy_allocation_phrase
    min_e = min_estimated_energy
    max_e = max_estimated_energy
    if min_e.present? && max_e.present?
      if min_e == max_e
        "exactly #{min_e}%"
      else
        "between #{min_e}% - #{max_e}%"
      end
    elsif max_e.present?
      "up to #{max_e}%"
    elsif min_e.present?
      "at least #{min_e}%"
    end
  end

  def blueprint_energy_allocation_sentence?
    (required? || suggested?) && blueprint_energy_allocation_phrase.present?
  end

  private

  def max_energy_greater_than_min_energy
    if max_estimated_energy < min_estimated_energy
      errors.add(:max_estimated_energy, "must be greater than minimum energy")
    end
  end
end 