# frozen_string_literal: true

module EligibilityRequirements
  class ValidateEligibilityHash
    # When +minimum_mileage_floor+ is nil (org/department defaults), skip absolute vs assignment floor check.
    def self.call(eligibility_hash, minimum_mileage_floor:)
      errors = []
      eligibility_hash.each do |key, value|
        next unless value.is_a?(Hash)

        if value['minimum_months_at_or_above_rating_criteria'].present? && value['minimum_months_at_or_above_rating_criteria'].to_i.negative?
          errors << "#{key.humanize}: Minimum months must be >= 0"
        end

        %w[minimum_percentage_of_assignments minimum_percentage_of_assignments_meeting minimum_percentage_of_assignments_exceeding].each do |pct_key|
          if value[pct_key].present? && (value[pct_key].to_f.negative? || value[pct_key].to_f > 100)
            errors << "#{key.humanize}: #{pct_key.humanize} must be between 0 and 100"
          end
        end
        %w[minimum_percentage_of_aspirational_values minimum_percentage_of_aspirational_values_meeting minimum_percentage_of_aspirational_values_exceeding].each do |pct_key|
          if value[pct_key].present? && (value[pct_key].to_f.negative? || value[pct_key].to_f > 100)
            errors << "#{key.humanize}: #{pct_key.humanize} must be between 0 and 100"
          end
        end
        if value['minimum_rating'].present? && key == 'position_check_in_requirements'
          rating = value['minimum_rating'].to_i
          errors << 'Position check-in minimum rating must be between -3 and 3' unless (-3..3).cover?(rating)
        end
      end

      mileage = eligibility_hash['mileage_requirements']
      if mileage.is_a?(Hash)
        if mileage['threshold_type'] == 'percentage'
          val = mileage['threshold_value']
          errors << 'Percentage more than required must be >= 0' if val.present? && val.to_i.negative?
        elsif minimum_mileage_floor
          val = mileage['threshold_value'].to_i
          errors << 'Minimum mileage points must be >= 0' if val.negative?
          if val < minimum_mileage_floor
            errors << "Minimum mileage points (#{val}) cannot be lower than the total from required assignments (#{minimum_mileage_floor})"
          end
        else
          val = mileage['threshold_value'].to_i
          errors << 'Minimum mileage points must be >= 0' if val.negative?
        end
      end

      errors
    end
  end
end
