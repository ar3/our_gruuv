# frozen_string_literal: true

FactoryBot.define do
  factory :assignment_flow do
    sequence(:name) { |n| "Assignment Flow #{n}" }
    association :company, factory: [:organization, :company]
    created_by { create(:teammate, :unassigned_employee, organization: company) }
    updated_by { created_by }
  end
end
