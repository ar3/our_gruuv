FactoryBot.define do
  factory :assignment_outcome do
    description { "Users report 90% satisfaction with product features" }
    outcome_type { "quantitative" }
    association :assignment
    
    trait :sentiment do
      outcome_type { "sentiment" }
      description { "Team agrees: We communicate clearly and frequently" }
    end
    
    trait :quantitative do
      outcome_type { "quantitative" }
      description { "Reduce response time to under 2 hours" }
    end
  end
end 