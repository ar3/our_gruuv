# frozen_string_literal: true

# HTTP MCP endpoint (Streamable HTTP, stateless).
# Auth: Bearer OAuth access token (preferred) or personal McpAccessToken.
# Unauthenticated → 401 + WWW-Authenticate resource_metadata for Claude discovery.
class McpController < ActionController::API
  before_action :authenticate_mcp_token!

  def handle
    server = Mcp::ServerFactory.build(agent_tools_context: @agent_tools_context)
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      allowed_hosts: mcp_allowed_hosts,
      allowed_origins: mcp_allowed_origins
    )
    status, headers, body = transport.handle_request(request)

    headers.each { |key, value| response.set_header(key, value) }
    self.status = status
    self.response_body = body
  end

  private

  def authenticate_mcp_token!
    auth = Mcp::Authenticate.call(authorization_header: request.authorization.to_s)
    unless auth.ok?
      response.set_header(
        "WWW-Authenticate",
        %(Bearer realm="OurGruuv MCP", resource_metadata="#{McpOauth::Urls.protected_resource_metadata}", scope="mcp")
      )
      render json: { error: auth.error }, status: :unauthorized
      return
    end

    @agent_tools_context = auth.context
    @mcp_token = auth.token
  end

  def mcp_allowed_hosts
    configured = ENV.fetch("MCP_ALLOWED_HOSTS", "").split(",").map(&:strip)
    rails_host = ENV["RAILS_HOST"].to_s.sub(%r{\Ahttps?://}i, "").split("/").first
    [
      *configured,
      rails_host,
      request.host,
      "localhost",
      "127.0.0.1",
      "www.example.com"
    ].filter_map { |h| h.to_s.split(":").first.presence }.uniq
  end

  def mcp_allowed_origins
    configured = ENV.fetch("MCP_ALLOWED_ORIGINS", "").split(",").map(&:strip)
    [
      *configured,
      "https://claude.ai",
      "https://claude.com"
    ].reject(&:blank?).uniq
  end
end
