FactoryBot.define do
  factory :huddle_participant do
    association :huddle
    association :teammate
    role { 'active' }
  end
end 