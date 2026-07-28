# frozen_string_literal: true

module McpOauth
  class IssueTokens
    Result = Data.define(:ok?, :payload, :error, :error_code)

    def self.call(**)
      new(**).call
    end

    def initialize(client:, person:, company_teammate:, scope:, resource: nil, include_refresh: true)
      @client = client
      @person = person
      @company_teammate = company_teammate
      @scope = scope.to_s
      @resource = resource
      @include_refresh = include_refresh
    end

    def call
      access, access_raw = McpOauthAccessToken.issue!(
        client: @client,
        person: @person,
        company_teammate: @company_teammate,
        scope: @scope,
        resource: @resource
      )

      payload = {
        access_token: access_raw,
        token_type: "Bearer",
        expires_in: [(access.expires_at - Time.current).to_i, 1].max,
        scope: @scope
      }

      if @include_refresh && @scope.split(/\s+/).include?("offline_access")
        _refresh, refresh_raw = McpOauthRefreshToken.issue!(
          client: @client,
          person: @person,
          company_teammate: @company_teammate,
          scope: @scope,
          resource: @resource
        )
        payload[:refresh_token] = refresh_raw
      end

      Result.new(ok?: true, payload: payload, error: nil, error_code: nil)
    end
  end
end
