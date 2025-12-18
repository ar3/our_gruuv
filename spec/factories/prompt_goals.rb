FactoryBot.define do
  factory :prompt_goal do
    association :prompt
    association :goal
  end
end


