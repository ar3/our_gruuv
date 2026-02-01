FactoryBot.define do
  factory :aspiration do
    association :company, factory: :company
    department { nil }
    name { "Aspiration #{rand(1000)}" }
    sort_order { rand(100) }
    semantic_version { "1.0.0" }

    trait :with_department do
      transient do
        department_name { "Engineering" }
      end

      after(:build) do |aspiration, evaluator|
        aspiration.department = create(:department, company: aspiration.company, name: evaluator.department_name)
      end
    end
  end
end
