FactoryBot.define do
  factory :highlights_redemption do
    association :organization
    association :company_teammate
    association :highlights_reward

    points_spent { 100.0 }
    status { 'pending' }
    fulfilled_at { nil }
    external_reference { nil }
    notes { nil }

    # Ensure reward and teammate are in the same organization
    after(:build) do |redemption|
      if redemption.organization && redemption.highlights_reward&.organization != redemption.organization
        redemption.highlights_reward = create(:highlights_reward, organization: redemption.organization)
      end
      if redemption.organization && redemption.company_teammate&.organization != redemption.organization
        redemption.company_teammate = create(:company_teammate, organization: redemption.organization)
      end
    end

    trait :pending do
      status { 'pending' }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :fulfilled do
      status { 'fulfilled' }
      fulfilled_at { Time.current }
      external_reference { "ext_ref_#{SecureRandom.hex(8)}" }
    end

    trait :failed do
      status { 'failed' }
      notes { "Failed: Payment processing error" }
    end

    trait :cancelled do
      status { 'cancelled' }
      notes { "Cancelled: User requested cancellation" }
    end
  end
end
