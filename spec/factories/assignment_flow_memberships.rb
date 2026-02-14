# frozen_string_literal: true

FactoryBot.define do
  factory :assignment_flow_membership do
    association :assignment_flow
    assignment { create(:assignment, company: assignment_flow.company) }
    placement { 0 }
    added_by { assignment_flow.created_by }
  end
end
