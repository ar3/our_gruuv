FactoryBot.define do
  factory :position_level do
    # Minor must be 1–3 for PositionLevel#eligibility_minor_slot (eligibility cascade).
    sequence(:level) { |n| "#{n}.#{((n - 1) % 3) + 1}" }
    association :position_major_level
  end
end