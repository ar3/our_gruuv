# frozen_string_literal: true

module EligibilityRequirements
  # Updates +owner+ minor-N FK to a find-or-created requirement row.
  class PersistMinorOnOwner
    Result = Struct.new(:errors, keyword_init: true)

    def self.call!(owner:, minor:, eligibility_params:, minimum_mileage_floor: nil)
      hash = BuildEligibilityHash.call(eligibility_params)
      errors = ValidateEligibilityHash.call(hash, minimum_mileage_floor: minimum_mileage_floor)
      return Result.new(errors: errors) if errors.any?

      requirement = FindOrCreate.call!(hash)
      fk_setter = :"minor_#{minor}_position_eligibility_requirement_id"
      owner.update!(fk_setter => requirement.id)
      Result.new(errors: [])
    end
  end
end
