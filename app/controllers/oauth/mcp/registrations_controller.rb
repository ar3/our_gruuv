# frozen_string_literal: true

module Oauth
  module Mcp
    # RFC 7591 Dynamic Client Registration for public (PKCE) clients.
    class RegistrationsController < ActionController::API
      def create
        body = parse_json_body
        redirect_uris = Array(body["redirect_uris"]).map(&:to_s).reject(&:blank?)
        if redirect_uris.empty?
          return render_oauth_error("invalid_client_metadata", "redirect_uris required", :bad_request)
        end

        client = McpOauthClient.create!(
          client_id: "ogdcr_#{SecureRandom.urlsafe_base64(24)}",
          client_name: body["client_name"],
          redirect_uris: redirect_uris,
          token_endpoint_auth_method: body["token_endpoint_auth_method"].presence || "none",
          grant_types: Array(body["grant_types"]).presence || %w[authorization_code refresh_token],
          response_types: Array(body["response_types"]).presence || %w[code],
          client_uri: body["client_uri"],
          logo_uri: body["logo_uri"],
          registration_source: "dcr"
        )

        render json: client.as_registration_response, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_oauth_error("invalid_client_metadata", e.message, :bad_request)
      end

      private

      def parse_json_body
        JSON.parse(request.raw_post.presence || "{}")
      rescue JSON::ParserError
        {}
      end

      def render_oauth_error(error, description, status)
        render json: { error: error, error_description: description }, status: status
      end
    end
  end
end
