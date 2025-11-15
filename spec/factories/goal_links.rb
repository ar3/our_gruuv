FactoryBot.define do
  factory :goal_link do
    association :this_goal, factory: :goal
    association :that_goal, factory: :goal
    link_type { 'this_blocks_that' }
    metadata { nil }
    
    trait :if_this_then_that do
      link_type { 'if_this_then_that' }
    end
    
    trait :this_blocks_that do
      link_type { 'this_blocks_that' }
    end
    
    trait :this_makes_that_easier do
      link_type { 'this_makes_that_easier' }
    end
    
    trait :this_makes_that_unnecessary do
      link_type { 'this_makes_that_unnecessary' }
    end
    
    trait :this_is_key_result_of_that do
      link_type { 'this_is_key_result_of_that' }
    end
    
    trait :this_supports_that do
      link_type { 'this_supports_that' }
    end
    
    trait :with_metadata do
      metadata { { notes: 'Sample notes', strength: 'medium' } }
    end
  end
end











