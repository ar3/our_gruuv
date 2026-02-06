FactoryBot.define do
  factory :kudos_points_ledger do
    association :company_teammate
    organization { company_teammate.organization }
    points_to_give { 50.0 }
    points_to_spend { 0.0 }

    trait :empty do
      points_to_give { 0.0 }
      points_to_spend { 0.0 }
    end

    trait :with_balance do
      points_to_give { 100.0 }
      points_to_spend { 50.0 }
    end
  end
end
