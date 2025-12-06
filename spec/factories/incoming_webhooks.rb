FactoryBot.define do
  factory :incoming_webhook do
    provider { 'slack' }
    event_type { 'message_action' }
    status { 'unprocessed' }
    payload { { 'type' => 'message_action', 'team' => { 'id' => 'T123456' } } }
    headers { { 'X-Slack-Request-Timestamp' => '1234567890', 'X-Slack-Signature' => 'v0=abc123' } }
    organization { nil }
    error_message { nil }
    processed_at { nil }

    trait :processed do
      status { 'processed' }
      processed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      error_message { 'Test error' }
      processed_at { Time.current }
    end

    trait :processing do
      status { 'processing' }
    end
  end
end

