# frozen_string_literal: true

FactoryBot.define do
  factory :possible_observation_slack_search do
    association :organization
    association :creator_company_teammate, factory: %i[company_teammate unassigned_employee]
    association :subject_company_teammate, factory: %i[company_teammate unassigned_employee]
    display_name { "Slack search about Pat (last 90 days)" }
    window_days { 90 }
    query { "<@USUBJECT> after:2026-01-01" }
    raw_results { { "version" => 1, "stored_in" => "active_storage", "messages_count" => 0 } }
    messages_count { 0 }
    search_status { "pending" }
    extractions { { "version" => 1, "items" => [] } }
    extraction_status { "ready" }

    after(:build) do |search|
      search.creator_company_teammate.organization = search.organization
      search.subject_company_teammate.organization = search.organization
    end

    trait :completed do
      search_status { "completed" }
      messages_count { 1 }
      raw_results do
        {
          "version" => 1,
          "stored_in" => "active_storage",
          "messages_count" => 1,
          "slack_total" => 1,
          "pages_fetched" => 1
        }
      end

      after(:create) do |search|
        payload = {
          "version" => 1,
          "query" => search.query,
          "window_days" => search.window_days,
          "messages" => [
            {
              "iid" => "msg-1",
              "team" => "T123",
              "channel_id" => "C123",
              "channel_name" => "general",
              "user" => "UOBS",
              "username" => "alex",
              "ts" => "1710000000.000100",
              "text" => "Pat did a great job on the launch.",
              "permalink" => "https://example.slack.com/archives/C123/p1710000000000100"
            }
          ]
        }
        search.raw_results_file.attach(
          io: StringIO.new(JSON.generate(payload)),
          filename: "slack_search_raw.json",
          content_type: "application/json"
        )
      end
    end

    trait :extracted do
      search_status { "completed" }
      extraction_status { "completed" }
      messages_count { 1 }
      after(:create) do |search|
        payload = {
          "version" => 1,
          "messages" => [
            {
              "channel_id" => "C123",
              "channel_name" => "general",
              "user" => "UOBS",
              "username" => "alex",
              "ts" => "1710000000.000100",
              "text" => "Pat did a great job on the launch.",
              "permalink" => "https://example.slack.com/archives/C123/p1710000000000100"
            }
          ]
        }
        search.raw_results_file.attach(
          io: StringIO.new(JSON.generate(payload)),
          filename: "slack_search_raw.json",
          content_type: "application/json"
        )
        search.update!(
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

    trait :failed do
      search_status { "failed" }
      search_error { "Slack search failed: invalid_auth" }
    end
  end
end
