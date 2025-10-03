FactoryBot.define do
  factory :teammate do
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
    
    trait :follower do
      first_employed_at { nil }
      last_terminated_at { nil }
    end
    
    trait :unassigned_employee do
      first_employed_at { 1.month.ago }
      last_terminated_at { nil }
    end
    
    trait :assigned_employee do
      first_employed_at { 1.month.ago }
      last_terminated_at { nil }
    end
    
    trait :terminated do
      first_employed_at { 6.months.ago }
      last_terminated_at { 1.month.ago }
    end
  end
end
