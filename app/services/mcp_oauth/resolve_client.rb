# frozen_string_literal: true

module McpOauth
  # Resolve CIMD client_id URLs or look up DCR-registered clients.
  class ResolveClient
    Result = Data.define(:ok?, :client, :error)

    def self.call(client_id:)
      new(client_id: client_id).call
    end

    def initialize(client_id:)
      @client_id = client_id.to_s
    end

    def call
      return failure("client_id required") if @client_id.blank?

      if cimd_url?
        resolve_cimd
      else
        client = McpOauthClient.find_active(@client_id)
        return failure("Unknown client_id") if client.nil?

        Result.new(ok?: true, client: client, error: nil)
      end
    end

    private

    def cimd_url?
      @client_id.match?(%r{\Ahttps://}i)
    end

    def resolve_cimd
      existing = McpOauthClient.find_active(@client_id)
      return Result.new(ok?: true, client: existing, error: nil) if existing

      uri = URI.parse(@client_id)
      return failure("CIMD client_id must be https") unless uri.scheme == "https"

      response = HTTP.timeout(connect: 3, read: 5).get(@client_id)
      return failure("Failed to fetch CIMD") unless response.status.success?

      meta = JSON.parse(response.body.to_s)
      redirect_uris = Array(meta["redirect_uris"])
      return failure("CIMD missing redirect_uris") if redirect_uris.blank?

      # MCP/CIMD: redirect_uris should be same-origin with client_id URL.
      unless redirect_uris.all? { |r| same_origin?(r, @client_id) || McpOauth::RedirectUri::LOOPBACK_HOSTS.include?(URI.parse(r).host) }
        return failure("CIMD redirect_uris must be same-origin or loopback")
      end

      client = McpOauthClient.create!(
        client_id: @client_id,
        client_name: meta["client_name"],
        redirect_uris: redirect_uris,
        token_endpoint_auth_method: meta["token_endpoint_auth_method"].presence || "none",
        grant_types: Array(meta["grant_types"]).presence || %w[authorization_code refresh_token],
        response_types: Array(meta["response_types"]).presence || %w[code],
        client_uri: meta["client_uri"],
        logo_uri: meta["logo_uri"],
        registration_source: "cimd"
      )

      Result.new(ok?: true, client: client, error: nil)
    rescue URI::InvalidURIError, JSON::ParserError => e
      failure(e.message)
    rescue HTTP::Error => e
      failure("CIMD fetch error: #{e.message}")
    end

    def same_origin?(redirect_uri, client_id_url)
      a = URI.parse(redirect_uri)
      b = URI.parse(client_id_url)
      a.scheme == b.scheme && a.host == b.host
    rescue URI::InvalidURIError
      false
    end

    def failure(message)
      Result.new(ok?: false, client: nil, error: message)
    end
  end
end
