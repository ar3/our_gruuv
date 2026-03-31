# frozen_string_literal: true

module Organizations
  class PositionEligibilityDefaultSeeder
    class << self
      def ensure!(organization)
        organization.reload
        return if organization.minor_1_position_eligibility_requirement_id.present?

        ids = [1, 2, 3].map do |minor|
          EligibilityRequirements::FindOrCreate.call!(PositionEligibilityRequirement.default_eligibility_hash_for_seed(minor)).id
        end

        organization.update_columns(
          minor_1_position_eligibility_requirement_id: ids[0],
          minor_2_position_eligibility_requirement_id: ids[1],
          minor_3_position_eligibility_requirement_id: ids[2],
          updated_at: Time.current
        )
      end

      def revert_org_links!(organization)
        organization.update_columns(
          minor_1_position_eligibility_requirement_id: nil,
          minor_2_position_eligibility_requirement_id: nil,
          minor_3_position_eligibility_requirement_id: nil,
          updated_at: Time.current
        )
      end
    end
  end
end
