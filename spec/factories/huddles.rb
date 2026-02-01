FactoryBot.define do
  factory :huddle do
    started_at { 1.day.ago }
    team

    trait :with_company do
      transient do
        company { nil }
      end

      after(:build) do |huddle, evaluator|
        if evaluator.company
          huddle.team = create(:team, company: evaluator.company)
        end
      end
    end
  end
end
