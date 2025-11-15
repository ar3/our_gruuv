FactoryBot.define do
  factory :goal_link do
    association :parent, factory: :goal
    association :child, factory: :goal
    metadata { nil }
    
    trait :with_metadata do
      metadata { { notes: 'Sample notes', strength: 'medium' } }
    end
  end
end











