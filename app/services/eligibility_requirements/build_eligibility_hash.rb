# frozen_string_literal: true

module EligibilityRequirements
  # Params shape matches organizations/positions/manage_eligibility form (`eligibility_requirements` root).
  class BuildEligibilityHash
    def self.call(eligibility_params)
      eligibility_params = eligibility_params.to_unsafe_h if eligibility_params.is_a?(ActionController::Parameters)
      eligibility_params = eligibility_params.deep_stringify_keys
      new_eligibility_data = {}

      mileage_params = eligibility_params['mileage_requirements']
      if mileage_params.present?
        mileage = mileage_params.to_h.stringify_keys
        threshold_type = mileage['threshold_type'].presence
        threshold_value = mileage['threshold_value']
        legacy_points = mileage['minimum_mileage_points']
        if threshold_type == 'percentage'
          if threshold_value.present? || threshold_value.to_s == '0'
            new_eligibility_data['mileage_requirements'] = { 'threshold_type' => 'percentage', 'threshold_value' => threshold_value.to_i }
          end
        elsif legacy_points.present?
          new_eligibility_data['mileage_requirements'] = { 'threshold_type' => 'absolute', 'threshold_value' => legacy_points.to_i }
        elsif threshold_type == 'absolute' && threshold_value.present?
          new_eligibility_data['mileage_requirements'] = { 'threshold_type' => 'absolute', 'threshold_value' => threshold_value.to_i }
        end
      end

      if eligibility_params['position_check_in_requirements'].present?
        pos_check = eligibility_params['position_check_in_requirements'].to_h.stringify_keys
        if pos_check['minimum_rating'].present? || pos_check['minimum_months_at_or_above_rating_criteria'].present?
          pos_data = {}
          pos_data['minimum_rating'] = pos_check['minimum_rating'].to_i if pos_check['minimum_rating'].present?
          if pos_check['minimum_months_at_or_above_rating_criteria'].present?
            pos_data['minimum_months_at_or_above_rating_criteria'] =
              pos_check['minimum_months_at_or_above_rating_criteria'].to_i
          end
          new_eligibility_data['position_check_in_requirements'] = pos_data if pos_data.any?
        end
      end

      if eligibility_params['required_assignment_check_in_requirements'].present?
        req_data = build_check_in_requirement_data(eligibility_params['required_assignment_check_in_requirements'], :assignments)
        new_eligibility_data['required_assignment_check_in_requirements'] = req_data if req_data.any?
      end

      if eligibility_params['unique_to_you_assignment_check_in_requirements'].present?
        unique_data =
          build_check_in_requirement_data(eligibility_params['unique_to_you_assignment_check_in_requirements'], :assignments)
        new_eligibility_data['unique_to_you_assignment_check_in_requirements'] = unique_data if unique_data.any?
      end

      if eligibility_params['company_aspirational_values_check_in_requirements'].present?
        company_data =
          build_check_in_requirement_data(eligibility_params['company_aspirational_values_check_in_requirements'], :aspirational_values)
        new_eligibility_data['company_aspirational_values_check_in_requirements'] = company_data if company_data.any?
      end

      new_eligibility_data
    end

    def self.build_check_in_requirement_data(params_hash, type)
      params_hash = params_hash.to_h.stringify_keys
      months = params_hash['minimum_months_at_or_above_rating_criteria'].presence
      if type == :assignments
        pct_meeting = params_hash['minimum_percentage_of_assignments_meeting'].presence
        pct_exceeding = params_hash['minimum_percentage_of_assignments_exceeding'].presence
      else
        pct_meeting = params_hash['minimum_percentage_of_aspirational_values_meeting'].presence
        pct_exceeding = params_hash['minimum_percentage_of_aspirational_values_exceeding'].presence
      end
      return {} if months.blank? || (pct_meeting.blank? && pct_exceeding.blank?)

      data = {}
      data['minimum_months_at_or_above_rating_criteria'] = months.to_i
      if type == :assignments
        data['minimum_percentage_of_assignments_meeting'] = pct_meeting.to_f if pct_meeting.present?
        data['minimum_percentage_of_assignments_exceeding'] = pct_exceeding.to_f if pct_exceeding.present?
      else
        data['minimum_percentage_of_aspirational_values_meeting'] = pct_meeting.to_f if pct_meeting.present?
        data['minimum_percentage_of_aspirational_values_exceeding'] = pct_exceeding.to_f if pct_exceeding.present?
      end
      data
    end
    private_class_method :build_check_in_requirement_data
  end
end
