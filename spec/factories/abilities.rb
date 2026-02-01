FactoryBot.define do
  factory :ability do
    sequence(:name) { |n| "Ability #{n}" }
    description { "A comprehensive ability description" }
    semantic_version { "1.0.0" }
    association :company, factory: :company
    department { nil }
    association :created_by, factory: :person
    association :updated_by, factory: :person

    trait :with_major_version do
      semantic_version { "2.0.0" }
    end

    trait :with_minor_version do
      semantic_version { "1.1.0" }
    end

    trait :with_patch_version do
      semantic_version { "1.0.1" }
    end

    trait :deprecated do
      semantic_version { "0.9.0" }
    end

    trait :with_department do
      transient do
        department_name { "Engineering" }
      end

      after(:build) do |ability, evaluator|
        ability.department = create(:department, company: ability.company, name: evaluator.department_name)
      end
    end
  end
end
