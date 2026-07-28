# frozen_string_literal: true

module McpOauth
  # Absolute URLs for MCP OAuth discovery and endpoints.
  module Urls
    module_function

    def base_url
      host = ENV.fetch("RAILS_HOST", "localhost")
      protocol = ENV.fetch("RAILS_ACTION_MAILER_DEFAULT_URL_PROTOCOL", "http")
      host = host.sub(%r{\Ahttps?://}i, "")
      "#{protocol}://#{host}"
    end

    def issuer
      ENV.fetch("MCP_OAUTH_ISSUER", base_url).to_s.chomp("/")
    end

    def mcp_resource
      ENV.fetch("MCP_RESOURCE_URL", "#{issuer}/mcp")
    end

    def protected_resource_metadata
      "#{issuer}/.well-known/oauth-protected-resource"
    end

    def authorization_server_metadata
      "#{issuer}/.well-known/oauth-authorization-server"
    end

    def authorize_url
      "#{issuer}/oauth/mcp/authorize"
    end

    def token_url
      "#{issuer}/oauth/mcp/token"
    end

    def registration_url
      "#{issuer}/oauth/mcp/register"
    end
  end
end
