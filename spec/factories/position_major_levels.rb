FactoryBot.define do
  factory :position_major_level do
    sequence(:set_name) { |n| "Engineering#{n}" }
    sequence(:major_level) { |n| "Senior#{n}" }
  end
end 