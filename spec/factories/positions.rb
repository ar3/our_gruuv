FactoryBot.define do
  factory :position do
    association :position_type
    association :position_level
    position_summary { "This position is responsible for developing software applications" }
    
    trait :with_assignments do
      after(:create) do |position|
        create_list(:position_assignment, 2, position: position, assignment_type: 'required')
        create_list(:position_assignment, 1, position: position, assignment_type: 'suggested')
      end
    end
    
    trait :with_external_references do
      after(:create) do |position|
        create(:external_reference, referable: position, reference_type: 'published', url: "https://docs.google.com/document/d/published-example")
        create(:external_reference, referable: position, reference_type: 'draft', url: "https://docs.google.com/document/d/draft-example")
      end
    end
  end
end 