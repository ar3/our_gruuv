FactoryBot.define do
  factory :huddle_participant do
    association :huddle
    association :person
    role { 'active' }
  end
end 