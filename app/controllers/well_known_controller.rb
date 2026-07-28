# frozen_string_literal: true

# RFC 9728 / RFC 8414 discovery for MCP OAuth.
class WellKnownController < ActionController::API
  def oauth_protected_resource
    render json: {
      resource: McpOauth::Urls.mcp_resource,
      authorization_servers: [McpOauth::Urls.issuer],
      scopes_supported: %w[mcp offline_access],
      bearer_methods_supported: %w[header],
      resource_documentation: "#{McpOauth::Urls.issuer}/organizations"
    }
  end

  # Path-aware variant: /.well-known/oauth-protected-resource/mcp
  def oauth_protected_resource_mcp
    oauth_protected_resource
  end

  def oauth_authorization_server
    render json: {
      issuer: McpOauth::Urls.issuer,
      authorization_endpoint: McpOauth::Urls.authorize_url,
      token_endpoint: McpOauth::Urls.token_url,
      registration_endpoint: McpOauth::Urls.registration_url,
      response_types_supported: %w[code],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: %w[S256],
      token_endpoint_auth_methods_supported: %w[none],
      scopes_supported: %w[mcp offline_access],
      client_id_metadata_document_supported: true,
      revocation_endpoint_auth_methods_supported: %w[none]
    }
  end
end
