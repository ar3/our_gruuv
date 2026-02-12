# frozen_string_literal: true

FactoryBot.define do
  factory :position_ability do
    association :position
    association :ability
    milestone_level { rand(1..5) }

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

    trait :same_organization do
      after(:build) do |pa|
        next unless pa.position && pa.ability
        pa.ability.company_id = pa.position.company.id
      end
    end
  end
end
