# frozen_string_literal: true

FactoryBot.define do
  factory :possible_observation_consult do
    association :organization
    association :creator_company_teammate, factory: %i[company_teammate unassigned_employee]
    display_name { "OG Consult #{SecureRandom.hex(4)}" }
    source_text { "Pat did a great job on the launch and crushed the timeline." }
    suggested_teammate_ids { [] }
    confirmed_teammate_ids { [] }
    people_status { "suggested" }
    extraction_status { "ready" }
    extractions { { "version" => 1, "items" => [] } }

    after(:build) do |consult|
      consult.creator_company_teammate.organization = consult.organization
    end

    trait :extracted do
      people_status { "confirmed" }
      extraction_status { "completed" }
      after(:create) do |consult|
        subject_id = Array(consult.confirmed_teammate_ids).first ||
                     create(:company_teammate, organization: consult.organization).id
        consult.update!(
          confirmed_teammate_ids: [subject_id],
          extractions: {
            "version" => 1,
            "processed_teammate_ids" => [subject_id],
            "items" => [
              {
                "id" => SecureRandom.uuid,
                "kind" => "kudos",
                "confidence" => 0.9,
                "quote" => "Summary: Pat crushed it.\n\nFull quote: great job",
                "summary" => "Pat crushed it.",
                "speaker_label" => "Alex",
                "recipient_label" => "Pat",
                "responder_company_teammate_id" => consult.creator_company_teammate_id,
                "subject_company_teammate_id" => subject_id,
                "include" => true
              }
            ]
          }
        )
      end
    end
  end
end
