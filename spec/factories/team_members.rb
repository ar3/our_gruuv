FactoryBot.define do
  factory :team_member do
    association :team
    association :company_teammate, factory: :company_teammate
  end
end
