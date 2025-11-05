FactoryBot.define do
  factory :goal do
    title { "Sample Goal" }
    description { "A sample goal description" }
    goal_type { 'inspirational_objective' }
    earliest_target_date { Date.today + 1.month }
    latest_target_date { Date.today + 3.months }
    most_likely_target_date { Date.today + 2.months }
    privacy_level { 'only_creator' }
    
    association :creator, factory: :teammate
    association :owner, factory: :person
    
    # Ensure date ordering when most_likely_target_date is overridden
    after(:build) do |goal|
      if goal.most_likely_target_date.present?
        # If most_likely is set but earliest/latest aren't, or if ordering is invalid, fix it
        if goal.earliest_target_date.nil? || goal.earliest_target_date > goal.most_likely_target_date
          goal.earliest_target_date = goal.most_likely_target_date - 1.month
        end
        if goal.latest_target_date.nil? || goal.latest_target_date < goal.most_likely_target_date
          goal.latest_target_date = goal.most_likely_target_date + 1.month
        end
      end
    end
    
    trait :inspirational_objective do
      goal_type { 'inspirational_objective' }
    end
    
    trait :qualitative_key_result do
      goal_type { 'qualitative_key_result' }
    end
    
    trait :quantitative_key_result do
      goal_type { 'quantitative_key_result' }
    end
    
    trait :with_person_owner do
      association :owner, factory: :person
    end
    
    trait :with_company_owner do
      association :owner, factory: [:organization, :company]
    end
    
    trait :with_team_owner do
      association :owner, factory: [:organization, :team]
    end
    
    trait :only_creator do
      privacy_level { 'only_creator' }
    end
    
    trait :only_creator_and_owner do
      privacy_level { 'only_creator_and_owner' }
    end
    
    trait :only_creator_owner_and_managers do
      privacy_level { 'only_creator_owner_and_managers' }
    end
    
    trait :everyone_in_company do
      privacy_level { 'everyone_in_company' }
    end
    
    trait :draft do
      started_at { nil }
      completed_at { nil }
      cancelled_at { nil }
    end
    
    trait :active do
      started_at { 1.day.ago }
      completed_at { nil }
      cancelled_at { nil }
    end
    
    trait :completed do
      started_at { 1.week.ago }
      completed_at { 1.day.ago }
      cancelled_at { nil }
    end
    
    trait :cancelled do
      started_at { 1.week.ago }
      completed_at { nil }
      cancelled_at { 1.day.ago }
    end
    
    trait :top_priority do
      became_top_priority { 1.day.ago }
    end
  end
end



