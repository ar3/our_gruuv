FactoryBot.define do
  factory :position_eligibility_requirement do
    transient do
      eligibility_hash { PositionEligibilityRequirement.default_eligibility_hash_for_seed(1) }
    end

    skip_create

    initialize_with do
      EligibilityRequirements::FindOrCreate.call!(eligibility_hash)
    end
  end
end
