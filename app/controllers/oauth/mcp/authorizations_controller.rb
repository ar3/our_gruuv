# frozen_string_literal: true

module Oauth
  module Mcp
    # Authorization Code + PKCE consent. Reuses Google session via ApplicationController.
    class AuthorizationsController < ApplicationController
      before_action :load_authorize_params, only: [:new, :create]
      before_action :require_login_for_oauth!, only: [:new, :create]

      layout "oauth"

      def new
        @client = resolve_client!
        return if performed?

        unless @client.allows_redirect_uri?(@redirect_uri)
          return render plain: "Invalid redirect_uri", status: :bad_request
        end

        unless @code_challenge.present? && @code_challenge_method == "S256"
          return render plain: "PKCE S256 code_challenge required", status: :bad_request
        end

        @teammates = current_person.company_teammates.includes(:organization).order(:id)
        @redirect_host = McpOauth::RedirectUri.display_host(@redirect_uri)
        @loopback_warning = McpOauth::RedirectUri::LOOPBACK_HOSTS.include?(@redirect_host)
      end

      def create
        @client = resolve_client!
        return if performed?

        unless @client.allows_redirect_uri?(@redirect_uri)
          return render plain: "Invalid redirect_uri", status: :bad_request
        end

        teammate = current_person.company_teammates.find_by(id: params[:company_teammate_id])
        unless teammate
          flash.now[:alert] = "Select an organization to connect."
          @teammates = current_person.company_teammates.includes(:organization).order(:id)
          @redirect_host = McpOauth::RedirectUri.display_host(@redirect_uri)
          @loopback_warning = McpOauth::RedirectUri::LOOPBACK_HOSTS.include?(@redirect_host)
          return render :new, status: :unprocessable_entity
        end

        scope = normalize_scope(@scope)
        _code, raw = McpOauthAuthorizationCode.issue!(
          client: @client,
          person: current_person,
          company_teammate: teammate,
          redirect_uri: @redirect_uri,
          code_challenge: @code_challenge,
          code_challenge_method: @code_challenge_method,
          scope: scope,
          resource: @resource
        )

        redirect_to build_redirect(@redirect_uri, code: raw, state: @state), allow_other_host: true
      end

      private

      def load_authorize_params
        @client_id = params[:client_id].to_s
        @redirect_uri = params[:redirect_uri].to_s
        @response_type = params[:response_type].to_s
        @scope = params[:scope].to_s
        @state = params[:state]
        @code_challenge = params[:code_challenge].to_s
        @code_challenge_method = params[:code_challenge_method].to_s.presence || "S256"
        @resource = params[:resource].presence
      end

      def require_login_for_oauth!
        return if current_person.present?

        session[:return_to] = request.fullpath
        redirect_to login_path, alert: "Sign in to connect Claude to OurGruuv."
      end

      def resolve_client!
        result = McpOauth::ResolveClient.call(client_id: @client_id)
        unless result.ok?
          render plain: result.error, status: :bad_request
          return nil
        end
        result.client
      end

      def normalize_scope(scope)
        parts = scope.to_s.split(/\s+/).reject(&:blank?)
        parts = %w[mcp] if parts.empty?
        parts |= %w[offline_access] if parts.include?("offline_access") || scope.blank?
        # Always allow refresh for Claude connectors.
        (parts | %w[mcp offline_access]).uniq.join(" ")
      end

      def build_redirect(uri, code:, state:)
        u = URI.parse(uri)
        q = Rack::Utils.parse_query(u.query)
        q["code"] = code
        q["state"] = state if state.present?
        u.query = q.to_query
        u.to_s
      end
    end
  end
end
