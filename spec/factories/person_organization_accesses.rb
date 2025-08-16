FactoryBot.define do
  factory :person_organization_access do
    association :person
    association :organization
    
    # Default to no permissions
    can_manage_employment { false }
    can_manage_maap { false }
    
    trait :employment_manager do
      can_manage_employment { true }
    end
    
    trait :maap_manager do
      can_manage_maap { true }
    end
    
    trait :full_access do
      can_manage_employment { true }
      can_manage_maap { true }
    end
  end
end
