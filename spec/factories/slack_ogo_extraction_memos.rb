# frozen_string_literal: true

FactoryBot.define do
  factory :slack_ogo_extraction_memo do
    association :subject_company_teammate, factory: :company_teammate
    context_fingerprint { Digest::SHA256.hexdigest("test-context") }
    prompt_version { Llm::SlackMomentsExtractor::PROMPT_VERSION }
    model_id { Llm::SlackMomentsExtractor.model_id }
    channel_id { "C#{SecureRandom.hex(4)}" }
    message_ts { "#{Time.current.to_i}.#{SecureRandom.random_number(100_000)}" }
    raw_items { [] }
  end
end
