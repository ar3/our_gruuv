# frozen_string_literal: true

FactoryBot.define do
  factory :ability_milestone_calibration do
    association :company_teammate, factory: :teammate
  end

  factory :ability_milestone_calibration_item do
    association :ability_milestone_calibration
    association :ability
  end
end
