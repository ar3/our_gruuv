# frozen_string_literal: true

FactoryBot.define do
  factory :slack_possible_observation do
    organization
    association :subject_company_teammate, factory: :company_teammate
    channel_id { "C#{SecureRandom.hex(4)}" }
    message_ts { "#{Time.current.to_i}.#{SecureRandom.random_number(100_000)}" }
    visibility { SlackPossibleObservation::VISIBILITY_PUBLIC }
    discoverer_company_teammate_ids { [] }
    payload do
      {
        "summary" => "Strong delivery on the launch",
        "quote" => "Pat crushed the timeline",
        "confidence" => 0.9,
        "permalink" => "https://example.slack.com/archives/#{channel_id}/p#{message_ts.delete('.')}",
        "speaker_label" => "alex",
        "channel_name" => "general"
      }
    end

    trait :private_or_dm do
      visibility { SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM }
    end

    trait :dismissed do
      dismissed_at { Time.current }
    end
  end
end
