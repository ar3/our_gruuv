FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    type { 'Company' }
    
    trait :company do
      type { 'Company' }
    end
    
    trait :team do
      type { 'Team' }
      association :parent, factory: [:organization, :company]
    end
    
    trait :with_slack_config do
      after(:create) do |organization|
        create(:slack_configuration, organization: organization)
      end
    end
  end
end 