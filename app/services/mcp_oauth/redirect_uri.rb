# frozen_string_literal: true

module McpOauth
  # Exact redirect match, plus RFC 8252 port-agnostic loopback for Claude Code.
  module RedirectUri
    CLAUDE_CALLBACK = "https://claude.ai/api/mcp/auth_callback"
    LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze

    module_function

    def allowed?(requested:, registered:)
      requested = requested.to_s
      return false if requested.blank?

      Array(registered).any? { |reg| match?(requested: requested, registered: reg.to_s) }
    end

    def match?(requested:, registered:)
      return true if requested == registered
      return true if registered == CLAUDE_CALLBACK && requested == CLAUDE_CALLBACK

      loopback_match?(requested: requested, registered: registered)
    end

    def loopback_match?(requested:, registered:)
      req = URI.parse(requested)
      reg = URI.parse(registered)
      return false unless LOOPBACK_HOSTS.include?(req.host) && LOOPBACK_HOSTS.include?(reg.host)
      return false unless req.scheme == "http" && reg.scheme == "http"
      return false unless normalize_path(req.path) == normalize_path(reg.path)

      # Port-agnostic for loopback (Claude Code ephemeral ports).
      true
    rescue URI::InvalidURIError
      false
    end

    def normalize_path(path)
      path.to_s.empty? ? "/" : path
    end

    def display_host(uri)
      URI.parse(uri.to_s).host
    rescue URI::InvalidURIError
      uri.to_s
    end
  end
end
