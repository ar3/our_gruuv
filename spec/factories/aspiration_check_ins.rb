FactoryBot.define do
  factory :aspiration_check_in do
    association :teammate
    association :aspiration
    check_in_started_on { Date.current }
    employee_rating { nil }
    manager_rating { nil }
    official_rating { nil }
    employee_private_notes { nil }
    manager_private_notes { nil }
    shared_notes { nil }
    employee_completed_at { nil }
    manager_completed_at { nil }
    manager_completed_by { nil }
    finalized_by { nil }
    official_check_in_completed_at { nil }
    maap_snapshot { nil }
    
    trait :employee_completed do
      employee_completed_at { 1.day.ago }
      employee_rating { 'meeting' }
      employee_private_notes { 'Employee notes' }
    end
    
    trait :manager_completed do
      manager_completed_at { 1.day.ago }
      manager_rating { 'meeting' }
      manager_private_notes { 'Manager notes' }
      manager_completed_by { association(:person) }
    end
    
    trait :ready_for_finalization do
      employee_completed_at { 1.day.ago }
      manager_completed_at { 1.day.ago }
      employee_rating { 'meeting' }
      manager_rating { 'meeting' }
      employee_private_notes { 'Employee notes' }
      manager_private_notes { 'Manager notes' }
      manager_completed_by { association(:person) }
    end
    
    trait :finalized do
      employee_completed_at { 2.days.ago }
      manager_completed_at { 2.days.ago }
      official_check_in_completed_at { 1.day.ago }
      employee_rating { 'meeting' }
      manager_rating { 'meeting' }
      official_rating { 'meeting' }
      employee_private_notes { 'Employee notes' }
      manager_private_notes { 'Manager notes' }
      shared_notes { 'Shared notes' }
      manager_completed_by { association(:person) }
      finalized_by { association(:person) }
    end
  end
end


