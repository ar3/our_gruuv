# frozen_string_literal: true

# Configure AWS Bedrock credentials for RubyLLM when AWS keys are present.
# Model id for transcript extraction is chosen in Llm::TranscriptMomentsExtractor (ENV).
RubyLLM.configure do |config|
  key = ENV['AWS_ACCESS_KEY_ID'].presence || Rails.application.credentials.dig(:aws, :access_key_id)
  secret = ENV['AWS_SECRET_ACCESS_KEY'].presence || Rails.application.credentials.dig(:aws, :secret_access_key)
  region = ENV['AWS_REGION'].presence || 'us-east-1'
  next if key.blank? || secret.blank?

  config.bedrock_api_key = key
  config.bedrock_secret_key = secret
  config.bedrock_region = region
  session = ENV['AWS_SESSION_TOKEN'].presence || Rails.application.credentials.dig(:aws, :session_token)
  config.bedrock_session_token = session if session.present?
end
