# frozen_string_literal: true

# HTTP MCP endpoint (Streamable HTTP, stateless). Auth: Bearer McpAccessToken.
class McpController < ActionController::API
  before_action :authenticate_mcp_token!

  # Handles POST (JSON-RPC), GET (SSE), DELETE (session) per Streamable HTTP.
  def handle
    server = Mcp::ServerFactory.build(agent_tools_context: @agent_tools_context)
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      allowed_hosts: mcp_allowed_hosts
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
      render json: { error: auth.error }, status: :unauthorized
      return
    end

    @agent_tools_context = auth.context
    @mcp_access_token = auth.token
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
      "www.example.com" # RSpec default host
    ].filter_map { |h| h.to_s.split(":").first.presence }.uniq
  end
end
