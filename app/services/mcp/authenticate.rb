# frozen_string_literal: true

module Mcp
  # Resolves Authorization: Bearer <token> → AgentTools::Context.
  class Authenticate
    Result = Data.define(:ok?, :context, :token, :error)

    def self.call(authorization_header:)
      new(authorization_header: authorization_header).call
    end

    def initialize(authorization_header:)
      @authorization_header = authorization_header.to_s
    end

    def call
      raw = extract_bearer
      return failure("Missing Bearer token") if raw.blank?

      token = McpAccessToken.authenticate(raw)
      return failure("Invalid or revoked MCP token") if token.nil?

      teammate = token.company_teammate
      return failure("Teammate missing") if teammate.nil?

      organization = teammate.organization
      context = Assistant::ContextBuilder.call(
        organization: organization,
        company_teammate: teammate
      )

      Result.new(ok?: true, context: context, token: token, error: nil)
    end

    private

    def extract_bearer
      match = @authorization_header.match(/\ABearer\s+(.+)\z/i)
      match && match[1].strip
    end

    def failure(message)
      Result.new(ok?: false, context: nil, token: nil, error: message)
    end
  end
end
