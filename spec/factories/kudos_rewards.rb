FactoryBot.define do
  factory :kudos_reward do
    association :organization

    sequence(:name) { |n| "Reward #{n}" }
    description { "A great reward for your hard work" }
    cost_in_points { 100.0 }
    reward_type { 'gift_card' }
    active { true }
    deleted_at { nil }
    metadata { {} }

    trait :gift_card do
      reward_type { 'gift_card' }
      metadata { { 'provider' => 'Tremendous', 'external_id' => 'gc_123' } }
    end

    trait :merchandise do
      reward_type { 'merchandise' }
      description { "Company branded merchandise" }
    end

    trait :experience do
      reward_type { 'experience' }
      description { "A memorable experience" }
    end

    trait :donation do
      reward_type { 'donation' }
      description { "Donate to a charity of your choice" }
    end

    trait :custom do
      reward_type { 'custom' }
    end

    trait :inactive do
      active { false }
    end

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :cheap do
      cost_in_points { 10.0 }
    end

    trait :expensive do
      cost_in_points { 500.0 }
    end
  end
end
