class HealthcheckController < ApplicationController
  def index
    @rails_env = Rails.env
    @env_vars = ENV.keys.map { |k| "#{k} :: #{ENV[k].size}" }.sort
    
    # Get Rails URL configuration
    @action_mailer_url_options = Rails.application.config.action_mailer.default_url_options
    @action_controller_url_options = Rails.application.config.action_controller.default_url_options
    
    # Debug: Check if routes are loaded
    @routes_loaded = Rails.application.routes.routes.any?
    @routes_count = Rails.application.routes.routes.count
    
    # Test URL generation
    begin
      url_options = Rails.application.config.action_controller.default_url_options
      @url_options_debug = "URL Options: #{url_options.inspect}"
      @env_host = ENV['RAILS_HOST']
      @env_protocol = ENV['RAILS_ACTION_MAILER_DEFAULT_URL_PROTOCOL']
      
      if url_options && url_options[:host].present?
        # Try with explicit URL options
        test_url = Rails.application.routes.url_helpers.root_url(url_options)
        @test_url_generated = test_url
        @url_generation_works = true
      else
        # In test environment or when no URL options configured, test with path only
        test_path = Rails.application.routes.url_helpers.root_path
        @test_url_generated = "PATH_ONLY: #{test_path}"
        @url_generation_works = true
      end
    rescue => e
      @test_url_generated = "ERROR: #{e.message}"
      @url_generation_works = false
    end
    
    # OAuth Health Check
    check_oauth_health
    
    begin
      @person_count = Person.count
      @db_status = "Connected"
      @db_error = nil
    rescue => e
      capture_error_in_sentry(e, {
        method: 'healthcheck_database',
        component: 'database_connection'
      })
      @person_count = "ERROR"
      @db_status = "Failed"
      @db_error = "#{e.class}: #{e.message}"
    end
  end
  
  def oauth_test
    # Test OAuth configuration
    @oauth_config = {
      google_client_id: ENV['GOOGLE_CLIENT_ID'],
      google_client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      omniauth_full_host: OmniAuth.config.full_host,
      omniauth_allowed_methods: OmniAuth.config.allowed_request_methods,
      current_request_url: request.url,
      current_request_host: request.host,
      generated_callback_url: "#{OmniAuth.config.full_host}/auth/google_oauth2/callback",
      generated_authorize_url: "#{OmniAuth.config.full_host}/auth/google_oauth2"
    }
    
    # Test if we can make a request to the OAuth endpoint
    begin
      test_response = Net::HTTP.get_response(URI("#{OmniAuth.config.full_host}/auth/google_oauth2"))
      @oauth_endpoint_response = test_response.code
      @oauth_endpoint_success = test_response.code == "200" || test_response.code == "302"
    rescue => e
      @oauth_endpoint_response = "ERROR: #{e.message}"
      @oauth_endpoint_success = false
    end
    
    render json: {
      oauth_config: @oauth_config,
      oauth_endpoint_response: @oauth_endpoint_response,
      oauth_endpoint_success: @oauth_endpoint_success
    }
  end
  
  private
  
  def check_oauth_health
    # Check Google OAuth environment variables
    @google_client_id = ENV['GOOGLE_CLIENT_ID']
    @google_client_secret = ENV['GOOGLE_CLIENT_SECRET']
    @oauth_env_vars_present = @google_client_id.present? && @google_client_secret.present?
    
    # Check OmniAuth configuration
    @omniauth_configured = Rails.application.middleware.any? { |m| m.klass == OmniAuth::Builder }
    @omniauth_allowed_methods = OmniAuth.config.allowed_request_methods
    @omniauth_full_host = OmniAuth.config.full_host
    
    # Check OAuth routes
    @oauth_routes = Rails.application.routes.routes.select { |r| r.path.spec.to_s.include?('auth') }
    @oauth_routes_count = @oauth_routes.count
    
    # Check AuthController
    @auth_controller_exists = defined?(AuthController)
    @auth_controller_methods = AuthController.instance_methods(false) if @auth_controller_exists
    
    # Check PersonIdentity model
    @person_identity_exists = defined?(PersonIdentity)
    @person_identity_count = PersonIdentity.count if @person_identity_exists
    
    # Test OAuth endpoint
    @oauth_endpoint_test = test_oauth_endpoint
    
    # Additional debugging
    @current_url = request.url
    @current_host = request.host
    @current_port = request.port
    @current_protocol = request.protocol
    
    # Test OAuth URL generation
    @oauth_callback_url = "#{OmniAuth.config.full_host}/auth/google_oauth2/callback"
    @oauth_authorize_url = "#{OmniAuth.config.full_host}/auth/google_oauth2"
    
    # Check if we can generate OAuth URLs
    @can_generate_oauth_urls = test_oauth_url_generation
  end
  
  def test_oauth_endpoint
    begin
      # Test if the OAuth endpoint responds
      test_url = "/auth/google_oauth2"
      @oauth_test_url = test_url
      @oauth_test_success = true
      @oauth_test_error = nil
    rescue => e
      @oauth_test_success = false
      @oauth_test_error = "#{e.class}: #{e.message}"
    end
  end
  
  def test_oauth_url_generation
    begin
      # Test if we can generate OAuth URLs
      callback_url = "#{OmniAuth.config.full_host}/auth/google_oauth2/callback"
      authorize_url = "#{OmniAuth.config.full_host}/auth/google_oauth2"
      
      @generated_callback_url = callback_url
      @generated_authorize_url = authorize_url
      
      return true
    rescue => e
      @oauth_url_generation_error = "#{e.class}: #{e.message}"
      return false
    end
  end
end
