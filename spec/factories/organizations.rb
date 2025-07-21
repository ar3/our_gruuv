FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    type { 'Team' }
  end
end 