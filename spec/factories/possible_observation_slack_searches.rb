# frozen_string_literal: true

FactoryBot.define do
  factory :possible_observation_slack_search do
    association :organization
    association :creator_company_teammate, factory: %i[company_teammate unassigned_employee]
    association :subject_company_teammate, factory: %i[company_teammate unassigned_employee]
    display_name { "Slack search about Pat (last 90 days)" }
    window_days { 90 }
    query { "<@USUBJECT> after:2026-01-01" }
    raw_results { { "version" => 1, "messages" => [] } }
    search_status { "pending" }
    extractions { { "version" => 1, "items" => [] } }
    extraction_status { "pending" }

    after(:build) do |search|
      search.creator_company_teammate.organization = search.organization
      search.subject_company_teammate.organization = search.organization
    end

    trait :completed do
      search_status { "completed" }
      raw_results do
        {
          "version" => 1,
          "query" => "<@USUBJECT> after:2026-01-01",
          "window_days" => 90,
          "total" => 1,
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
      end
    end

    trait :failed do
      search_status { "failed" }
      search_error { "Slack search failed: invalid_auth" }
    end
  end
end
