FactoryBot.define do
  factory :observation do
    association :observer, factory: :person
    association :company, factory: [:organization, :company]
    story { "Great work on the project! #{rand(1000)}" }
    privacy_level { :observed_only }
    primary_feeling { 'happy' }
    secondary_feeling { nil }
    observed_at { Time.current }
    custom_slug { nil }
    deleted_at { nil }

    # Include at least one observee by default to satisfy validation
    after(:build) do |observation|
      # Create a teammate in the same company as the observation
      teammate = create(:teammate, organization: observation.company)
      observation.observees.build(teammate: teammate)
    end

    trait :observer_only do
      privacy_level { :observer_only }
    end

    trait :observed_only do
      privacy_level { :observed_only }
    end

    trait :managers_only do
      privacy_level { :managers_only }
    end

    trait :observed_and_managers do
      privacy_level { :observed_and_managers }
    end

    trait :public do
      privacy_level { :public_observation }
    end

    trait :public_observation do
      privacy_level { :public_observation }
    end

    trait :journal do
      privacy_level { :observer_only }
    end

    trait :soft_deleted do
      deleted_at { Time.current }
    end

    trait :with_observees do
      after(:create) do |observation|
        create_list(:observee, 2, observation: observation, teammate: create(:teammate, organization: observation.company))
      end
    end

    trait :with_ratings do
      after(:create) do |observation|
        create(:observation_rating, observation: observation, rateable: create(:ability, organization: observation.company), rating: :strongly_agree)
        create(:observation_rating, observation: observation, rateable: create(:assignment, organization: observation.company), rating: :agree)
      end
    end
  end
end
