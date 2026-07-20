# frozen_string_literal: true

module GoogleMeet
  # HTTP client for Meet / Drive APIs using a teammate's google_meet TeammateIdentity.
  class OauthClient
    HTTP_CONNECT_TIMEOUT = 10
    HTTP_READ_TIMEOUT = 60

    def initialize(teammate)
      @teammate = teammate
      @identity = teammate.google_meet_identity
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

      response = http.post("https://oauth2.googleapis.com/token", form: {
        grant_type: "refresh_token",
        client_id: ENV["GOOGLE_CLIENT_ID"],
        client_secret: ENV["GOOGLE_CLIENT_SECRET"],
        refresh_token: refresh_token
      })
      data = JSON.parse(response.body.to_s)

      unless data["access_token"]
        Rails.logger.error "Google Meet token refresh failed: #{data['error'] || 'Unknown error'}"
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
      Rails.logger.error "Google Meet token refresh error: #{e.message}"
      false
    end

    def get_json(url, params: {})
      ensure_fresh_token!
      response = authorized_get(url, params: params)
      if response.status == 401 && refresh_access_token!
        response = authorized_get(url, params: params)
      end
      parse_json_response(response)
    end

    def get_body(url, params: {}, accept: nil)
      ensure_fresh_token!
      response = authorized_get(url, params: params, accept: accept)
      if response.status == 401 && refresh_access_token!
        response = authorized_get(url, params: params, accept: accept)
      end
      raise ApiError, "Google API error #{response.status}: #{response.body.to_s.truncate(500)}" unless response.status.success?

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

    def authorized_get(url, params: {}, accept: nil)
      request = http.auth("Bearer #{access_token}")
      request = request.headers("Accept" => accept) if accept.present?
      request.get(url, params: params)
    end

    def parse_json_response(response)
      body = response.body.to_s
      data = body.present? ? JSON.parse(body) : {}
      unless response.status.success?
        message = data["error"].is_a?(Hash) ? data.dig("error", "message") : data["error"]
        raise ApiError, "Google API error #{response.status}: #{message || body.truncate(500)}"
      end
      data
    end

    def http
      HTTP.timeout(connect: HTTP_CONNECT_TIMEOUT, read: HTTP_READ_TIMEOUT)
    end
  end
end
