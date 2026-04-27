# frozen_string_literal: true

FactoryBot.define do
  factory :possible_observation_transcript do
    association :organization
    association :creator_company_teammate, factory: %i[company_teammate unassigned_employee]
    display_name { 'Meeting Transcript 2026-01-01' }
    extractions { { 'version' => 1, 'items' => [] } }
    extraction_status { 'pending' }

    after(:build) do |transcript|
      transcript.creator_company_teammate.organization = transcript.organization
    end

    trait :with_file do
      after(:create) do |transcript|
        transcript.transcript_file.attach(
          io: Rails.root.join('spec/fixtures/files/transcript_sample.txt').open,
          filename: 'transcript_sample.txt',
          content_type: 'text/plain'
        )
      end
    end

    trait :completed do
      extraction_status { 'completed' }
      extractions do
        {
          'version' => 1,
          'items' => [
            {
              'id' => '00000000-0000-4000-8000-000000000001',
              'kind' => 'kudos',
              'quote' => 'Great job on the launch.',
              'speaker_label' => 'Alice',
              'recipient_label' => 'Bob',
              'responder_company_teammate_id' => nil,
              'subject_company_teammate_id' => nil,
              'observer_unknown' => true,
              'observee_unknown' => true,
              'feedback_request_id' => nil,
              'include' => true
            }
          ]
        }
      end
    end
  end
end
