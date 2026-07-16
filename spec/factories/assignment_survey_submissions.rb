FactoryBot.define do
  factory :assignment_survey_submission do
    association :company_teammate, factory: :company_teammate
    organization { company_teammate.organization }
    status { "draft" }
    finalized_at { nil }

    trait :finalized do
      status { "finalized" }
      finalized_at { Time.current }
    end
  end
end
