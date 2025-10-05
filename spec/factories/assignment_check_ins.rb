FactoryBot.define do
  factory :assignment_check_in do
    association :teammate
    association :assignment
    check_in_started_on { Date.current }
    actual_energy_percentage { 50 }
    employee_rating { 'meeting' }
    manager_rating { 'meeting' }
    employee_personal_alignment { 'like' }
    employee_private_notes { 'Test notes' }
    manager_private_notes { 'Manager test notes' }
    shared_notes { 'Shared test notes' }

    trait :employee_completed do
      employee_completed_at { Time.current }
    end

    trait :manager_completed do
      manager_completed_at { Time.current }
    end

    trait :ready_for_finalization do
      employee_completed_at { Time.current }
      manager_completed_at { Time.current }
    end

    trait :officially_completed do
      employee_completed_at { Time.current }
      manager_completed_at { Time.current }
      official_check_in_completed_at { Time.current }
      official_rating { 'meeting' }
    end

    trait :with_high_energy do
      actual_energy_percentage { 80 }
    end

    trait :with_low_energy do
      actual_energy_percentage { 20 }
    end

    trait :exceeding_expectations do
      employee_rating { 'exceeding' }
      manager_rating { 'exceeding' }
      official_rating { 'exceeding' }
    end

    trait :working_to_meet do
      employee_rating { 'working_to_meet' }
      manager_rating { 'working_to_meet' }
      official_rating { 'working_to_meet' }
    end
  end
end