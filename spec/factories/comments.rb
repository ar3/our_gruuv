FactoryBot.define do
  factory :comment do
    body { "This is a test comment" }
    association :organization, factory: :organization
    association :creator, factory: :person
    
    trait :on_assignment do
      association :commentable, factory: :assignment
    end
    
    trait :on_ability do
      association :commentable, factory: :ability
    end
    
    trait :on_aspiration do
      association :commentable, factory: :aspiration
    end
    
    trait :resolved do
      resolved_at { Time.current }
    end
    
    trait :with_replies do
      after(:create) do |comment|
        create_list(:comment, 2, commentable: comment, organization: comment.organization, creator: comment.creator)
      end
    end
  end
end
