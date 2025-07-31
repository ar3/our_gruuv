FactoryBot.define do
  factory :position_type do
    external_title { "Software Engineer" }
    alternative_titles { "Developer\nProgrammer\nCoder" }
    position_summary { "Develops software applications and systems" }
    association :organization, factory: :organization
    association :position_major_level
    
    trait :with_external_references do
      after(:create) do |position_type|
        create(:external_reference, referable: position_type, reference_type: 'published', url: "https://docs.google.com/document/d/published-example")
        create(:external_reference, referable: position_type, reference_type: 'draft', url: "https://docs.google.com/document/d/draft-example")
      end
    end
  end
end 