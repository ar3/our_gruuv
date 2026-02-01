FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    type { 'Company' }
    
    trait :company do
      type { 'Company' }
    end
    
    # DEPRECATED: STI Department has been removed. Use create(:department, company: company) instead.
    # This trait is kept for backwards compatibility but creates a Company type.
    trait :department do
      type { 'Company' }
    end
    
    # DEPRECATED: STI Team has been removed. Use create(:team, company: company) instead.
    # This trait is kept for backwards compatibility but creates a Company type.
    trait :team do
      type { 'Company' }
    end
    
    trait :with_slack_config do
      after(:create) do |organization|
        create(:slack_configuration, organization: organization)
      end
    end
  end

  # Alias for easier factory creation
  factory :company, parent: :organization do
    type { 'Company' }
  end
end
