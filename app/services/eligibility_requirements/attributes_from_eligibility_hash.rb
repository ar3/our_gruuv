# frozen_string_literal: true

module EligibilityRequirements
  # Converts the string-key hash produced by BuildEligibilityHash into DB attributes (no fingerprint).
  class AttributesFromEligibilityHash
    def self.call(eligibility_hash)
      hash = eligibility_hash.stringify_keys
      attrs = {
        mileage_threshold_type: nil,
        mileage_threshold_value: nil,
        position_check_in_minimum_rating: nil,
        position_check_in_minimum_months: nil,
        required_assignment_minimum_months: nil,
        required_assignment_pct_meeting: nil,
        required_assignment_pct_exceeding: nil,
        unique_to_you_minimum_months: nil,
        unique_to_you_pct_meeting: nil,
        unique_to_you_pct_exceeding: nil,
        aspirational_minimum_months: nil,
        aspirational_pct_meeting: nil,
        aspirational_pct_exceeding: nil
      }

      mileage = hash['mileage_requirements']
      if mileage.is_a?(Hash)
        mileage = mileage.stringify_keys
        attrs[:mileage_threshold_type] = mileage['threshold_type'].presence
        attrs[:mileage_threshold_value] = mileage['threshold_value'].presence&.to_i
      end

      pc = hash['position_check_in_requirements']
      if pc.is_a?(Hash)
        pc = pc.stringify_keys
        attrs[:position_check_in_minimum_rating] = pc['minimum_rating'].presence&.to_i
        attrs[:position_check_in_minimum_months] = pc['minimum_months_at_or_above_rating_criteria'].presence&.to_i
      end

      ra = hash['required_assignment_check_in_requirements']
      if ra.is_a?(Hash)
        ra = ra.stringify_keys
        attrs[:required_assignment_minimum_months] = ra['minimum_months_at_or_above_rating_criteria'].presence&.to_i
        attrs[:required_assignment_pct_meeting] = ra['minimum_percentage_of_assignments_meeting'].presence&.to_d
        attrs[:required_assignment_pct_exceeding] = ra['minimum_percentage_of_assignments_exceeding'].presence&.to_d
      end

      uy = hash['unique_to_you_assignment_check_in_requirements']
      if uy.is_a?(Hash)
        uy = uy.stringify_keys
        attrs[:unique_to_you_minimum_months] = uy['minimum_months_at_or_above_rating_criteria'].presence&.to_i
        attrs[:unique_to_you_pct_meeting] = uy['minimum_percentage_of_assignments_meeting'].presence&.to_d
        attrs[:unique_to_you_pct_exceeding] = uy['minimum_percentage_of_assignments_exceeding'].presence&.to_d
      end

      asp = hash['company_aspirational_values_check_in_requirements']
      if asp.is_a?(Hash)
        asp = asp.stringify_keys
        attrs[:aspirational_minimum_months] = asp['minimum_months_at_or_above_rating_criteria'].presence&.to_i
        attrs[:aspirational_pct_meeting] = asp['minimum_percentage_of_aspirational_values_meeting'].presence&.to_d
        attrs[:aspirational_pct_exceeding] = asp['minimum_percentage_of_aspirational_values_exceeding'].presence&.to_d
      end

      attrs
    end
  end
end
