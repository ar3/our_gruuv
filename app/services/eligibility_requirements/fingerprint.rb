# frozen_string_literal: true

require 'digest'

module EligibilityRequirements
  class Fingerprint
    ORDERED_KEYS = %i[
      mileage_threshold_type mileage_threshold_value
      position_check_in_minimum_rating position_check_in_minimum_months
      required_assignment_minimum_months required_assignment_pct_meeting required_assignment_pct_exceeding
      unique_to_you_minimum_months unique_to_you_pct_meeting unique_to_you_pct_exceeding
      aspirational_minimum_months aspirational_pct_meeting aspirational_pct_exceeding
    ].freeze

    def self.compute(attributes_hash)
      payload = ORDERED_KEYS.to_h { |k| [k.to_s, normalize_value(attributes_hash[k])] }
      Digest::SHA256.hexdigest(JSON.generate(payload))
    end

    def self.normalize_value(value)
      case value
      when nil then nil
      when BigDecimal then value.to_s('F')
      when Float then format('%.10g', value)
      else value.to_s
      end
    end
  end
end
