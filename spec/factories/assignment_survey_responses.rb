FactoryBot.define do
  factory :assignment_survey_response do
    association :submission, factory: :assignment_survey_submission
    assignment { association :assignment, company: submission.organization }
    assignment_source { "active" }
    snapshot_title { assignment.title }
    snapshot_tagline { assignment.tagline }
    snapshot_required_activities { assignment.required_activities }
    snapshot_outcomes { [] }
    understandable_rating { nil }
    possible_rating { nil }
    relevant_rating { nil }
    comment { nil }

    trait :complete do
      understandable_rating { 5 }
      possible_rating { 4 }
      relevant_rating { 6 }
    end
  end
end
