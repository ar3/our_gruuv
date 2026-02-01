FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    type { 'Company' }
    
    trait :company do
      type { 'Company' }
    end
    
    trait :department do
      type { 'Department' }
      association :parent, factory: [:organization, :company]
    end
    
    # DEPRECATED: STI Team has been removed. Use create(:team, company: company) instead.
    # This trait now creates a Department for backwards compatibility.
    trait :team do
      type { 'Department' }
      association :parent, factory: [:organization, :company]
    end
    
    trait :with_slack_config do
      after(:create) do |organization|
        create(:slack_configuration, organization: organization)
      end
    end
  end
end


