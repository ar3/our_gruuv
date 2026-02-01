FactoryBot.define do
  factory :title do
    external_title { "Software Engineer" }
    alternative_titles { "Developer\nProgrammer\nCoder" }
    position_summary { "Develops software applications and systems" }
    association :company, factory: :company
    association :position_major_level
    department { nil }
    
    trait :with_external_references do
      after(:create) do |title|
        create(:external_reference, referable: title, reference_type: 'published', url: "https://docs.google.com/document/d/published-example")
        create(:external_reference, referable: title, reference_type: 'draft', url: "https://docs.google.com/document/d/draft-example")
      end
    end

    trait :with_department do
      transient do
        department_name { "Engineering" }
      end

      after(:build) do |title, evaluator|
        title.department = create(:department, company: title.company, name: evaluator.department_name)
      end
    end
  end
end
