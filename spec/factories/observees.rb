FactoryBot.define do
  factory :observee do
    association :observation
    association :teammate

    # Ensure teammate is in same company as observation
    after(:build) do |observee|
      if observee.observation&.company && observee.teammate&.organization != observee.observation.company
        observee.teammate = create(:teammate, organization: observee.observation.company)
      end
    end
  end
end
