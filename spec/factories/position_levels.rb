FactoryBot.define do
  factory :position_level do
    sequence(:level) { |n| "#{n}.0" }
    association :position_major_level
  end
end 