# frozen_string_literal: true

module Oauth
  module Mcp
    # Token endpoint: authorization_code + refresh_token (form-urlencoded).
    class TokensController < ActionController::API
      def create
        grant = params[:grant_type].to_s

        case grant
        when "authorization_code"
          handle_authorization_code
        when "refresh_token"
          handle_refresh_token
        else
          render_oauth_error("unsupported_grant_type", "grant_type must be authorization_code or refresh_token")
        end
      end

      private

      def handle_authorization_code
        client_result = McpOauth::ResolveClient.call(client_id: params[:client_id])
        return render_oauth_error("invalid_client", client_result.error) unless client_result.ok?

        client = client_result.client
        code = params[:code].to_s
        redirect_uri = params[:redirect_uri].to_s
        verifier = params[:code_verifier].to_s

        record = McpOauthAuthorizationCode.consume(code)
        return render_oauth_error("invalid_grant", "Invalid or expired authorization code") if record.nil?
        return render_oauth_error("invalid_grant", "client_id mismatch") unless record.mcp_oauth_client_id == client.id
        return render_oauth_error("invalid_grant", "redirect_uri mismatch") unless record.redirect_uri == redirect_uri

        unless McpOauth::Pkce.valid?(
          code_verifier: verifier,
          code_challenge: record.code_challenge,
          method: record.code_challenge_method
        )
          return render_oauth_error("invalid_grant", "PKCE verification failed")
        end

        issued = McpOauth::IssueTokens.call(
          client: client,
          person: record.person,
          company_teammate: record.company_teammate,
          scope: record.scope,
          resource: record.resource,
          include_refresh: true
        )
        render json: issued.payload
      end

      def handle_refresh_token
        client_result = McpOauth::ResolveClient.call(client_id: params[:client_id])
        return render_oauth_error("invalid_client", client_result.error) unless client_result.ok?

        client = client_result.client
        refresh = McpOauthRefreshToken.find_active(params[:refresh_token])
        return render_oauth_error("invalid_grant", "Invalid refresh token") if refresh.nil?
        return render_oauth_error("invalid_grant", "client_id mismatch") unless refresh.mcp_oauth_client_id == client.id

        refresh.mark_rotated!

        issued = McpOauth::IssueTokens.call(
          client: client,
          person: refresh.person,
          company_teammate: refresh.company_teammate,
          scope: refresh.scope,
          resource: refresh.resource,
          include_refresh: true
        )
        render json: issued.payload
      end

      def render_oauth_error(error, description, status: :bad_request)
        render json: { error: error, error_description: description }, status: status
      end
    end
  end
end
