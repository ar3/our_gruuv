FactoryBot.define do
  factory :employment_tenure do
    association :teammate
    association :company, factory: [:organization, :company]
    started_at { 1.month.ago }
    ended_at { nil } # Default to active employment
    
    transient do
      manager { nil } # Accept Person or CompanyTeammate for backward compatibility
    end
    
    after(:build) do |employment_tenure, evaluator|
      # Create a position with the correct relationships for this company
      position_major_level = create(:position_major_level)
      position_type = create(:position_type, organization: employment_tenure.company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level)
      employment_tenure.position = create(:position, position_type: position_type, position_level: position_level)
      
      # Handle legacy 'manager' parameter (Person) by converting to manager_teammate
      if evaluator.manager
        if evaluator.manager.is_a?(Person)
          manager_teammate = CompanyTeammate.find_or_create_by(
            person: evaluator.manager,
            organization: employment_tenure.company
          )
          employment_tenure.manager_teammate = manager_teammate
        elsif evaluator.manager.is_a?(CompanyTeammate)
          employment_tenure.manager_teammate = evaluator.manager
        end
      end
    end
    
    trait :with_manager do
      transient do
        manager_person { nil }
      end
      
      after(:build) do |employment_tenure, evaluator|
        if evaluator.manager_person
          manager_teammate = CompanyTeammate.find_or_create_by(
            person: evaluator.manager_person,
            organization: employment_tenure.company
          )
          employment_tenure.manager_teammate = manager_teammate
        end
      end
    end
    
    trait :with_seat do
      after(:build) do |employment_tenure|
        # Override the default position creation to use the seat's position type
        if employment_tenure.seat
          position_type = employment_tenure.seat.position_type
          position_level = create(:position_level, position_major_level: position_type.position_major_level)
          employment_tenure.position = create(:position, position_type: position_type, position_level: position_level)
        end
      end
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
