FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Team #{n}" }
    association :company, factory: [:organization, :company]

    trait :archived do
      deleted_at { Time.current }
    end

    trait :with_members do
      transient do
        member_count { 3 }
      end

      after(:create) do |team, evaluator|
        create_list(:team_member, evaluator.member_count, team: team)
      end
    end
  end
end
