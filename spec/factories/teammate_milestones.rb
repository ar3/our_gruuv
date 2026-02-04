FactoryBot.define do
  factory :teammate_milestone do
    association :company_teammate, factory: :company_teammate
    association :ability
    milestone_level { rand(1..5) }
    attained_at { Date.current }

    # Create certifying_teammate if not provided
    after(:build) do |milestone|
      unless milestone.certifying_teammate
        cert_teammate = build(:company_teammate, organization: milestone.company_teammate.organization)
        cert_teammate.save!
        milestone.certifying_teammate = cert_teammate
      end
    end

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
