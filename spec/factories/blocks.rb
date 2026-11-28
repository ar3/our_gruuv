# frozen_string_literal: true

FactoryBot.define do
  factory :block do
    association :document
    block_type { "text" }
    position { 1 }
    content { "Block markdown content" }
    settings { {} }
  end
end
