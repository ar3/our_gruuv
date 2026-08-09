# frozen_string_literal: true

FactoryBot.define do
  factory :object_maintainer do
    association :company_teammate, factory: [ :company_teammate, :assigned_employee ]
    association :maintainable, factory: :assignment
    association :added_by, factory: [ :company_teammate, :assigned_employee ]

    trait :for_assignment do
      association :maintainable, factory: :assignment
    end

    trait :for_position do
      association :maintainable, factory: :position
    end

    trait :for_ability do
      association :maintainable, factory: :ability
    end
  end
end
