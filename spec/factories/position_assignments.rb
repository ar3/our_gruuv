FactoryBot.define do
  factory :position_assignment do
    association :position
    association :assignment
    assignment_type { "required" }
    
    trait :required do
      assignment_type { "required" }
    end
    
    trait :suggested do
      assignment_type { "suggested" }
    end
  end
end 