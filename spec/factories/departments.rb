FactoryBot.define do
  factory :department do
    sequence(:name) { |n| "Department #{n}" }
    association :company, factory: :company
    parent_department { nil }

    trait :with_parent do
      transient do
        parent_name { "Parent Department" }
      end

      after(:build) do |department, evaluator|
        department.parent_department = create(:department, company: department.company, name: evaluator.parent_name)
      end
    end

    trait :archived do
      deleted_at { Time.current }
    end
  end
end
