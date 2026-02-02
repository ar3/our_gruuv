FactoryBot.define do
  factory :assignment_ability do
    association :assignment
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
      after(:build) do |assignment_ability|
        # Ensure assignment and ability belong to same company
        if assignment_ability.assignment&.company && assignment_ability.ability&.company
          assignment_ability.ability.company = assignment_ability.assignment.company
        end
      end
    end
  end
end
