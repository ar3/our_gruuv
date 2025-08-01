FactoryBot.define do
  factory :assignment do
    title { "Product Manager" }
    tagline { "We create products that users love and that drive business growth" }
    required_activities { "• Lead product strategy and roadmap\n• Conduct user research and interviews\n• Define product requirements" }
    handbook { "Focus on user needs and business impact. Always validate assumptions with data." }
    association :company, factory: :organization
    
    trait :with_source_urls do
      after(:create) do |assignment|
        create(:external_reference, referable: assignment, reference_type: 'published', url: "https://docs.google.com/document/d/published-example")
        create(:external_reference, referable: assignment, reference_type: 'draft', url: "https://docs.google.com/document/d/draft-example")
      end
    end
    
    trait :with_outcomes do
      after(:create) do |assignment|
        create_list(:assignment_outcome, 3, assignment: assignment)
      end
    end
    
    trait :with_mixed_outcomes do
      after(:create) do |assignment|
        create(:assignment_outcome, :quantitative, assignment: assignment)
        create(:assignment_outcome, :sentiment, assignment: assignment)
        create(:assignment_outcome, :quantitative, assignment: assignment)
      end
    end
  end
end 