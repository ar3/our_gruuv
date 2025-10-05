FactoryBot.define do
  factory :person_milestone do
    association :teammate
    association :ability
    association :certified_by, factory: :person
    milestone_level { rand(1..5) }
    attained_at { Date.current }

    trait :milestone_1 do
      milestone_level { 1 }
    end

    trait :milestone_2 do
      milestone_level { 2 }
    end

    trait :milestone_3 do
      milestone_level { 3 }
    end

    trait :milestone_4 do
      milestone_level { 4 }
    end

    trait :milestone_5 do
      milestone_level { 5 }
    end

    trait :recent do
      attained_at { 1.week.ago }
    end

    trait :old do
      attained_at { 6.months.ago }
    end
  end
end
