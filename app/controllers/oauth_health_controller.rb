class OauthHealthController < ApplicationController
  def check
    @health_status = {
      environment_variables: check_environment_variables,
      omniauth_config: check_omniauth_config,
      routes: check_routes,
      middleware: check_middleware,
      test_request: test_oauth_request
    }
  end

  private

  def check_environment_variables
    {
      google_client_id: ENV['GOOGLE_CLIENT_ID'].present?,
      google_client_secret: ENV['GOOGLE_CLIENT_SECRET'].present?,
      google_client_id_value: ENV['GOOGLE_CLIENT_ID']&.first(20) + '...',
      google_client_secret_value: ENV['GOOGLE_CLIENT_SECRET']&.first(20) + '...'
    }
  end

  def check_omniauth_config
    {
      allowed_request_methods: OmniAuth.config.allowed_request_methods,
      full_host: OmniAuth.config.full_host,
      test_mode: OmniAuth.config.test_mode
    }
  rescue => e
    { error: e.message }
  end

  def check_routes
    routes = Rails.application.routes.routes.map(&:path).map(&:spec).map(&:to_s)
    {
      auth_routes: routes.select { |r| r.include?('auth') },
      google_oauth_routes: routes.select { |r| r.include?('google_oauth2') }
    }
  end

  def check_middleware
    middleware = Rails.application.middleware.map(&:class).map(&:name)
    {
      omniauth_middleware: middleware.include?('OmniAuth::Builder'),
      csrf_middleware: middleware.select { |m| m.include?('CSRF') }
    }
  end

  def test_oauth_request
    begin
      # Test if we can create an OAuth client
      client = OAuth2::Client.new(
        ENV['GOOGLE_CLIENT_ID'],
        ENV['GOOGLE_CLIENT_SECRET'],
        site: 'https://accounts.google.com',
        authorize_url: '/o/oauth2/auth',
        token_url: '/o/oauth2/token'
      )
      
      {
        oauth_client_created: true,
        client_id: client.id.present?,
        client_secret: client.secret.present?
      }
    rescue => e
      {
        oauth_client_created: false,
        error: e.message
      }
    end
  end
end

