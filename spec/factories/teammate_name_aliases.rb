# frozen_string_literal: true

FactoryBot.define do
  factory :teammate_name_alias do
    association :company_teammate
    sequence(:name) { |n| "Alias#{n}" }
    source { "manual" }
  end
end
