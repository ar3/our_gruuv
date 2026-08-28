FactoryBot.define do
  factory :assignment_survey_response do
    association :company_teammate, factory: :company_teammate
    organization { company_teammate.organization }
    assignment { association :assignment, company: organization }
    assignment_source { "active" }
    snapshot_title { assignment.title }
    snapshot_tagline { assignment.tagline }
    snapshot_required_activities { assignment.required_activities }
    snapshot_outcomes { [] }
    understandable_rating { nil }
    possible_rating { nil }
    relevant_rating { nil }
    comment { nil }
    personal_alignment { nil }
    submitted_at { nil }

    trait :submitted do
      submitted_at { Time.current }
    end

    trait :complete do
      understandable_rating { 5 }
      possible_rating { 4 }
      relevant_rating { 6 }
      submitted_at { Time.current }
    end

    trait :partial do
      personal_alignment { "like" }
    end
  end
end
