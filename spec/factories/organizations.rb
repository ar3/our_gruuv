FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }

    # Backwards compatibility traits - no-op since STI type column was removed
    # These traits are kept for test backwards compatibility
    trait :company do
      # No-op, all organizations are now "companies"
    end

    # DEPRECATED: Use create(:department, company: organization) for real departments
    trait :department do
      # No-op - kept for backwards compatibility
    end

    # DEPRECATED: Use create(:team, company: organization) for real teams
    trait :team do
      # No-op - kept for backwards compatibility
    end

    trait :with_slack_config do
      after(:create) do |organization|
        create(:slack_configuration, organization: organization)
      end
    end
  end

  # Alias for easier factory creation - points to organization (Company STI removed)
  factory :company, parent: :organization
end
