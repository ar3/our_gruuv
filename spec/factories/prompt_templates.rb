FactoryBot.define do
  factory :prompt_template do
    association :company, factory: [:organization, :company]
    title { "Performance Review Questions" }
    description { "A set of questions for quarterly performance reviews" }
    available_at { Date.current }
    is_primary { false }
    is_secondary { false }
    is_tertiary { false }

    trait :primary do
      is_primary { true }
    end

    trait :secondary do
      is_secondary { true }
    end

    trait :tertiary do
      is_tertiary { true }
    end

    trait :available do
      available_at { Date.current }
    end

    trait :unavailable do
      available_at { nil }
    end

    trait :future do
      available_at { 1.week.from_now }
    end
  end
end

