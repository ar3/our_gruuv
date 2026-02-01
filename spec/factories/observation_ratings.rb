FactoryBot.define do
  factory :observation_rating do
    association :observation
    rating { :agree }

    trait :strongly_agree do
      rating { :strongly_agree }
    end

    trait :agree do
      rating { :agree }
    end

    trait :na do
      rating { :na }
    end

    trait :disagree do
      rating { :disagree }
    end

    trait :strongly_disagree do
      rating { :strongly_disagree }
    end

    trait :positive do
      rating { [:strongly_agree, :agree].sample }
    end

    trait :negative do
      rating { [:disagree, :strongly_disagree].sample }
    end

    trait :with_ability do
      after(:build) do |rating|
        rating.rateable = create(:ability, company: rating.observation.company)
      end
    end

    trait :with_assignment do
      after(:build) do |rating|
        rating.rateable = create(:assignment, company: rating.observation.company)
      end
    end

    trait :with_aspiration do
      after(:build) do |rating|
        rating.rateable = create(:aspiration, company: rating.observation.company)
      end
    end

    # Default to ability if no rateable specified
    after(:build) do |rating|
      if rating.rateable.nil?
        rating.rateable = create(:ability, company: rating.observation.company)
      end
    end
  end
end
