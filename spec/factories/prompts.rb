FactoryBot.define do
  factory :prompt do
    company_teammate { CompanyTeammate.create!(person: create(:person), organization: create(:organization, :company)) }
    association :prompt_template
    closed_at { nil }

    trait :open do
      closed_at { nil }
    end

    trait :closed do
      closed_at { Time.current }
    end
  end
end

