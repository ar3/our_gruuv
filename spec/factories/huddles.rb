FactoryBot.define do
  factory :huddle do
    association :organization
    started_at { 1.day.ago }
    
    # Use sequence to ensure unique aliases for different huddles
    sequence(:huddle_alias) { |n| "test-huddle-#{n}" }
  end
end 