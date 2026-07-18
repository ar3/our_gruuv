# frozen_string_literal: true

FactoryBot.define do
  factory :possible_observation_slack_search_batch do
    association :possible_observation_slack_search
    position { 1 }
    message_keys { [] }
    messages_count { 0 }
    extraction_status { "ready" }
    extractions { { "version" => 1, "items" => [] } }

    trait :ready_with_message do
      after(:create) do |batch|
        search = batch.possible_observation_slack_search
        message = {
          "channel_id" => "C123",
          "channel_name" => "general",
          "user" => "UOBS",
          "username" => "alex",
          "ts" => "1710000000.000100",
          "text" => "Pat did a great job on the launch and crushed the timeline completely.",
          "permalink" => "https://example.slack.com/archives/C123/p1710000000000100"
        }
        search.raw_results_file.attach(
          io: StringIO.new(JSON.generate("version" => 1, "messages" => [message])),
          filename: "slack_search_raw.json",
          content_type: "application/json"
        )
        search.update!(search_status: "completed", messages_count: 1, filtered_messages_count: 1)
        batch.update!(
          message_keys: [PossibleObservationSlackSearchBatch.message_key(message)],
          messages_count: 1,
          newest_ts: message["ts"],
          oldest_ts: message["ts"]
        )
      end
    end

    trait :extracted do
      extraction_status { "completed" }
      after(:create) do |batch|
        search = batch.possible_observation_slack_search
        message = {
          "channel_id" => "C123",
          "channel_name" => "general",
          "user" => "UOBS",
          "username" => "alex",
          "ts" => "1710000000.000100",
          "text" => "Pat did a great job on the launch and crushed the timeline completely.",
          "permalink" => "https://example.slack.com/archives/C123/p1710000000000100"
        }
        search.raw_results_file.attach(
          io: StringIO.new(JSON.generate("version" => 1, "messages" => [message])),
          filename: "slack_search_raw.json",
          content_type: "application/json"
        )
        search.update!(search_status: "completed", messages_count: 1, filtered_messages_count: 1)
        batch.update!(
          message_keys: [PossibleObservationSlackSearchBatch.message_key(message)],
          messages_count: 1,
          newest_ts: message["ts"],
          oldest_ts: message["ts"],
          extractions: {
            "version" => 1,
            "items" => [
              {
                "id" => "00000000-0000-4000-8000-000000000099",
                "kind" => "kudos",
                "quote" => "Summary: Pat crushed it.\n\n====================\n\nFull quote: Pat did a great job.",
                "summary" => "Pat crushed it.",
                "short_quote" => "Pat did a great job.",
                "full_quote" => "Pat did a great job on the launch.",
                "speaker_label" => "alex",
                "recipient_label" => "Pat",
                "responder_company_teammate_id" => search.creator_company_teammate_id,
                "subject_company_teammate_id" => search.subject_company_teammate_id,
                "observer_unknown" => false,
                "observee_unknown" => false,
                "channel_id" => "C123",
                "ts" => "1710000000.000100",
                "permalink" => "https://example.slack.com/archives/C123/p1710000000000100",
                "slack_user_id" => "UOBS",
                "include" => true
              }
            ]
          }
        )
      end
    end
  end
end
