# frozen_string_literal: true

# Immutable requirement profile: application only INSERTs rows; updates are not used.
class PositionEligibilityRequirement < ApplicationRecord
  self.table_name = 'position_eligibility_requirements'

  has_many :positions, inverse_of: :position_eligibility_requirement, dependent: :restrict_with_exception

  # Rebuild the hash shape expected by PositionEligibilityService / views (milestone_requirements always absent here).
  def to_eligibility_service_hash
    h = {}
    if mileage_threshold_type.present?
      h['mileage_requirements'] = {
        'threshold_type' => mileage_threshold_type,
        'threshold_value' => mileage_threshold_value
      }
    end
    if position_check_in_minimum_rating.present? || position_check_in_minimum_months.present?
      h['position_check_in_requirements'] = {
        'minimum_rating' => position_check_in_minimum_rating,
        'minimum_months_at_or_above_rating_criteria' => position_check_in_minimum_months
      }.compact
    end
    if required_assignment_minimum_months.present? || required_assignment_pct_meeting.present? || required_assignment_pct_exceeding.present?
      h['required_assignment_check_in_requirements'] = {
        'minimum_months_at_or_above_rating_criteria' => required_assignment_minimum_months,
        'minimum_percentage_of_assignments_meeting' => required_assignment_pct_meeting&.to_f,
        'minimum_percentage_of_assignments_exceeding' => required_assignment_pct_exceeding&.to_f
      }.compact
    end
    if unique_to_you_minimum_months.present? || unique_to_you_pct_meeting.present? || unique_to_you_pct_exceeding.present?
      h['unique_to_you_assignment_check_in_requirements'] = {
        'minimum_months_at_or_above_rating_criteria' => unique_to_you_minimum_months,
        'minimum_percentage_of_assignments_meeting' => unique_to_you_pct_meeting&.to_f,
        'minimum_percentage_of_assignments_exceeding' => unique_to_you_pct_exceeding&.to_f
      }.compact
    end
    if aspirational_minimum_months.present? || aspirational_pct_meeting.present? || aspirational_pct_exceeding.present?
      h['company_aspirational_values_check_in_requirements'] = {
        'minimum_months_at_or_above_rating_criteria' => aspirational_minimum_months,
        'minimum_percentage_of_aspirational_values_meeting' => aspirational_pct_meeting&.to_f,
        'minimum_percentage_of_aspirational_values_exceeding' => aspirational_pct_exceeding&.to_f
      }.compact
    end
    h
  end

  # Default seed payload (matches former PositionEligibilityService defaults); identical for minors 1–3.
  def self.default_eligibility_hash_for_seed(_minor = nil)
    {
      'company_aspirational_values_check_in_requirements' => {
        'minimum_months_at_or_above_rating_criteria' => 3,
        'minimum_percentage_of_aspirational_values_meeting' => 80,
        'minimum_percentage_of_aspirational_values_exceeding' => 0
      },
      'required_assignment_check_in_requirements' => {
        'minimum_months_at_or_above_rating_criteria' => 3,
        'minimum_percentage_of_assignments_meeting' => 80,
        'minimum_percentage_of_assignments_exceeding' => 0
      },
      'unique_to_you_assignment_check_in_requirements' => {
        'minimum_months_at_or_above_rating_criteria' => 0,
        'minimum_percentage_of_assignments_meeting' => 0,
        'minimum_percentage_of_assignments_exceeding' => 0
      },
      'position_check_in_requirements' => {
        'minimum_rating' => 2,
        'minimum_months_at_or_above_rating_criteria' => 3
      },
      'mileage_requirements' => {
        'threshold_type' => 'percentage',
        'threshold_value' => 20
      }
    }
  end
end
