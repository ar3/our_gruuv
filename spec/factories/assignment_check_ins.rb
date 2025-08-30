FactoryBot.define do
  factory :assignment_check_in do
    association :person
    association :assignment
    check_in_started_on { Date.current }
    actual_energy_percentage { rand(10..50) }
    employee_rating { :meeting }
    manager_rating { :meeting }
    official_rating { :meeting }
    employee_personal_alignment { :like }
    employee_private_notes { "Feeling good about this assignment" }
    manager_private_notes { "Employee is performing well" }
    shared_notes { "Making steady progress" }
  end

  trait :working_to_meet do
    employee_rating { :working_to_meet }
    manager_rating { :working_to_meet }
    official_rating { :working_to_meet }
  end

  trait :exceeding do
    employee_rating { :exceeding }
    manager_rating { :exceeding }
    official_rating { :exceeding }
  end

  trait :high_energy do
    actual_energy_percentage { rand(60..100) }
  end

  trait :low_energy do
    actual_energy_percentage { rand(1..30) }
  end

  trait :love_assignment do
    employee_personal_alignment { :love }
  end

  trait :prefer_not do
    employee_personal_alignment { :prefer_not }
  end

  trait :closed do
    check_in_ended_on { Date.current }
  end
end
