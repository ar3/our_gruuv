FactoryBot.define do
  factory :huddle do
    association :organization
    started_at { 1.day.ago }
    huddle_alias { nil }
  end
end 