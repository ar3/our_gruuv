# frozen_string_literal: true

module EligibilityRequirements
  class FindOrCreate
    class << self
      def call!(eligibility_hash)
        attrs = AttributesFromEligibilityHash.call(eligibility_hash)
        fp = Fingerprint.compute(attrs)
        existing = PositionEligibilityRequirement.find_by(requirements_fingerprint: fp)
        return existing if existing

        begin
          PositionEligibilityRequirement.create!(attrs.merge(requirements_fingerprint: fp))
        rescue ActiveRecord::RecordNotUnique
          PositionEligibilityRequirement.find_by!(requirements_fingerprint: fp)
        end
      end
    end
  end
end
