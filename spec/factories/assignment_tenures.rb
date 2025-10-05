FactoryBot.define do
  factory :assignment_tenure do
    association :teammate
    association :assignment
    started_at { Date.current }
    ended_at { nil } # Active by default
    anticipated_energy_percentage { rand(10..50) } # Random percentage between 10-50%
  end

  trait :inactive do
    ended_at { 1.month.ago }
  end

  trait :with_high_energy do
    anticipated_energy_percentage { rand(60..100) }
  end

  trait :with_low_energy do
    anticipated_energy_percentage { rand(1..30) }
  end

  trait :without_start_date do
    started_at { nil }
  end
end
