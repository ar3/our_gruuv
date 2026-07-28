# frozen_string_literal: true

FactoryBot.define do
  factory :mcp_access_token do
    transient do
      raw_token { nil }
    end

    name { "Claude Desktop" }

    after(:build) do |token, evaluator|
      if token.company_teammate.nil?
        person = token.person || create(:person)
        token.person = person
        token.company_teammate = create(:teammate, person: person)
      else
        token.person = token.company_teammate.person
      end

      raw = evaluator.raw_token.presence || "ogmcp_#{SecureRandom.urlsafe_base64(24)}"
      token.token_digest = McpAccessToken.digest(raw)
      token.define_singleton_method(:raw_token_for_specs) { raw }
    end
  end
end
