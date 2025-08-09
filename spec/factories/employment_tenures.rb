FactoryBot.define do
  factory :employment_tenure do
    association :person
    association :company, factory: [:organization, :company]
    started_at { 1.month.ago }
    ended_at { nil } # Default to active employment
    
    after(:build) do |employment_tenure|
      # Create a position with the correct relationships for this company
      position_major_level = create(:position_major_level)
      position_type = create(:position_type, organization: employment_tenure.company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level)
      employment_tenure.position = create(:position, position_type: position_type, position_level: position_level)
    end
    
    trait :with_manager do
      association :manager, factory: :person
    end
    
    trait :inactive do
      ended_at { 1.week.ago }
    end
    
    trait :recent do
      started_at { 1.week.ago }
    end
    
    trait :long_term do
      started_at { 1.year.ago }
    end
  end
end
