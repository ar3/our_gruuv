# frozen_string_literal: true

module Zoom
  # HTTP client for Zoom APIs using a teammate's zoom TeammateIdentity.
  class OauthClient
    HTTP_CONNECT_TIMEOUT = 10
    HTTP_READ_TIMEOUT = 60
    API_BASE = "https://api.zoom.us/v2"

    def initialize(teammate)
      @teammate = teammate
      @identity = teammate.zoom_identity
    end

    def authenticated?
      @identity.present? && access_token.present?
    end

    def access_token
      @identity&.raw_credentials&.dig("token")
    end

    def refresh_token
      @identity&.raw_credentials&.dig("refresh_token")
    end

    def refresh_access_token!
      return false if refresh_token.blank?

      response = http.basic_auth(user: ENV["ZOOM_CLIENT_ID"], pass: ENV["ZOOM_CLIENT_SECRET"])
                     .post(
                       "https://zoom.us/oauth/token",
                       form: {
                         grant_type: "refresh_token",
                         refresh_token: refresh_token
                       }
                     )
      data = JSON.parse(response.body.to_s)

      unless data["access_token"]
        Rails.logger.error "Zoom token refresh failed: #{data['reason'] || data['error'] || 'Unknown error'}"
        return false
      end

      @identity.raw_data ||= {}
      @identity.raw_data["credentials"] ||= {}
      @identity.raw_data["credentials"]["token"] = data["access_token"]
      if data["refresh_token"].present?
        @identity.raw_data["credentials"]["refresh_token"] = data["refresh_token"]
      end
      @identity.raw_data["credentials"]["expires_at"] =
        data["expires_in"] ? (Time.current + data["expires_in"].to_i.seconds).iso8601 : nil
      @identity.save!
      true
    rescue StandardError => e
      Rails.logger.error "Zoom token refresh error: #{e.message}"
      false
    end

    def get_json(path, params: {})
      ensure_fresh_token!
      url = path.start_with?("http") ? path : "#{API_BASE}#{path}"
      response = authorized_get(url, params: params)
      if response.status == 401 && refresh_access_token!
        response = authorized_get(url, params: params)
      end
      parse_json_response(response)
    end

    def get_body(url)
      ensure_fresh_token!
      # Zoom download URLs often redirect; access_token query avoids Authorization-header drop.
      uri = URI.parse(url)
      query = URI.decode_www_form(uri.query.to_s)
      query.reject! { |k, _| k == "access_token" }
      query << ["access_token", access_token]
      uri.query = URI.encode_www_form(query)

      response = http.follow.get(uri.to_s)
      if response.status == 401 && refresh_access_token!
        query = URI.decode_www_form(URI.parse(url).query.to_s)
        query.reject! { |k, _| k == "access_token" }
        query << ["access_token", access_token]
        uri = URI.parse(url)
        uri.query = URI.encode_www_form(query)
        response = http.follow.get(uri.to_s)
      end
      raise ApiError, "Zoom download error #{response.status}: #{response.body.to_s.truncate(500)}" unless response.status.success?

      response.body.to_s
    end

    class ApiError < StandardError; end

    private

    def ensure_fresh_token!
      expires_at = @identity&.raw_credentials&.dig("expires_at")
      return if expires_at.blank?

      parsed = Time.zone.parse(expires_at.to_s)
      return if parsed.blank? || parsed > 2.minutes.from_now

      refresh_access_token!
    end

    def authorized_get(url, params: {})
      http.auth("Bearer #{access_token}").get(url, params: params)
    end

    def parse_json_response(response)
      body = response.body.to_s
      data = body.present? ? JSON.parse(body) : {}
      unless response.status.success?
        message = data["message"].presence || data["reason"].presence || data["error"]
        raise ApiError, "Zoom API error #{response.status}: #{message || body.truncate(500)}"
      end
      data
    end

    def http
      HTTP.timeout(connect: HTTP_CONNECT_TIMEOUT, read: HTTP_READ_TIMEOUT)
    end
  end
end
