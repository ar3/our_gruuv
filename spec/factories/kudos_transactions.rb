FactoryBot.define do
  factory :kudos_transaction do
    association :company_teammate
    organization { company_teammate.organization }
    points_to_give_delta { 0 }
    points_to_spend_delta { 0 }
    type { 'KudosTransaction' }

    trait :positive_give do
      points_to_give_delta { 10 }
    end

    trait :positive_spend do
      points_to_spend_delta { 10 }
    end

    trait :negative_give do
      points_to_give_delta { -5 }
    end

    trait :negative_spend do
      points_to_spend_delta { -5 }
    end
  end

  factory :bank_award_transaction, parent: :kudos_transaction, class: 'BankAwardTransaction' do
    type { 'BankAwardTransaction' }
    company_teammate_banker do
      association :company_teammate,
        organization: company_teammate.organization,
        can_manage_kudos_rewards: true
    end
    reason { "Welcome to the team!" }
    points_to_give_delta { 50 }
    points_to_spend_delta { 0 }
  end

  factory :observer_give_transaction, parent: :kudos_transaction, class: 'ObserverGiveTransaction' do
    type { 'ObserverGiveTransaction' }
    association :observation
    points_to_give_delta { -10 }
    points_to_spend_delta { 0 }
  end

  factory :points_exchange_transaction, parent: :kudos_transaction, class: 'PointsExchangeTransaction' do
    type { 'PointsExchangeTransaction' }
    association :observation
    points_to_give_delta { 0 }
    points_to_spend_delta { 10 }
  end

  factory :kickback_reward_transaction, parent: :kudos_transaction, class: 'KickbackRewardTransaction' do
    type { 'KickbackRewardTransaction' }
    association :observation
    points_to_give_delta { 5 }
    points_to_spend_delta { 0 }
  end

  factory :celebratory_award_transaction, parent: :kudos_transaction, class: 'CelebratoryAwardTransaction' do
    type { 'CelebratoryAwardTransaction' }
    observable_moment do
      association :observable_moment, :new_hire,
        company: organization,
        primary_potential_observer: company_teammate
    end
    points_to_give_delta { 50 }
    points_to_spend_delta { 25 }
  end

  factory :redemption_transaction, parent: :kudos_transaction, class: 'RedemptionTransaction' do
    type { 'RedemptionTransaction' }
    kudos_redemption do
      association :kudos_redemption,
        organization: organization,
        company_teammate: company_teammate
    end
    points_to_give_delta { 0 }
    points_to_spend_delta { -100 }
    reason { "Redeemed reward" }
  end
end
