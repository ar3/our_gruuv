class HealthcheckController < ApplicationController
  def index
    @rails_env = Rails.env
    @show_env_vars = params[:show_env_vars] == 'true'
    
    if @show_env_vars
      @env_vars = ENV.keys.map { |k| "#{k} :: #{ENV[k].size}" }.sort
    end
    
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
    
    # Database Health Check
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
    
    render :index
  end
  
  def oauth
    check_oauth_health
    render :oauth
  end

  def search
    check_search_health
    render :search
  end

  def notification_api
    check_notification_api_health
    render :notification_api
  end

  def giphy
    check_giphy_health
    render :giphy
  end

  def test_notification_api
    unless notification_api_configured?
      render json: { 
        success: false, 
        error: 'NotificationAPI not configured. Please set NOTIFICATION_API_CLIENT_ID and NOTIFICATION_API_CLIENT_SECRET environment variables.' 
      }, status: :unprocessable_entity
      return
    end

    phone_number = params[:phone_number] || '+13172898859'
    
    # Validate phone number format (basic E.164 format check)
    unless phone_number.match?(/^\+[1-9]\d{1,14}$/)
      render json: { 
        success: false, 
        error: 'Invalid phone number format. Please use E.164 format (e.g., +15005550006)' 
      }, status: :unprocessable_entity
      return
    end

    begin
      service = NotificationApiService.new(
        client_id: ENV['NOTIFICATION_API_CLIENT_ID'],
        client_secret: ENV['NOTIFICATION_API_CLIENT_SECRET']
      )
      
      # Use the provided phone number or default
      result = service.test_connection(
        to: {
          id: phone_number,
          number: phone_number
        }
      )
      
      if result.is_a?(Hash) && result[:success] == false
        # Service returned error details
        render json: { 
          success: false, 
          error: result[:error],
          status: result[:status],
          headers: result[:headers],
          backtrace: result[:backtrace],
          full_response: result
        }, status: :unprocessable_entity
      elsif result
        render json: { 
          success: true, 
          message: "Test notification sent successfully to #{phone_number}!",
          response: result
        }
      else
        render json: { 
          success: false, 
          error: 'Failed to send test notification. Check logs for details.' 
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "NotificationAPI test error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        success: false, 
        error: "Error: #{e.message}" 
      }, status: :unprocessable_entity
    end
  end

  def test_giphy
    unless giphy_configured?
      render json: { 
        success: false, 
        error: 'GIPHY not configured. Please set GIPHY_API_KEY environment variable.' 
      }, status: :unprocessable_entity
      return
    end

    begin
      gateway = Giphy::Gateway.new
      # Perform a simple search to test the connection
      gifs = gateway.search_gifs(query: 'test', limit: 1)
      
      render json: { 
        success: true, 
        message: "GIPHY API connection successful! Found #{gifs.length} GIF(s).",
        gifs_found: gifs.length
      }
    rescue Giphy::Gateway::RetryableError => e
      Rails.logger.error "GIPHY test retryable error: #{e.message}"
      render json: { 
        success: false, 
        error: "Service temporarily unavailable: #{e.message}" 
      }, status: :service_unavailable
    rescue Giphy::Gateway::NonRetryableError => e
      Rails.logger.error "GIPHY test error: #{e.message}"
      render json: { 
        success: false, 
        error: "GIPHY API error: #{e.message}" 
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "GIPHY test unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        success: false, 
        error: "Error: #{e.message}" 
      }, status: :unprocessable_entity
    end
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

  def check_search_health
    begin
      @search_health = PgSearchHealthService.check
      @search_healthy = @search_health[:healthy]
      @search_error = nil
    rescue => e
      capture_error_in_sentry(e, {
        method: 'healthcheck_search',
        component: 'pg_search_indexes'
      })
      @search_health = nil
      @search_healthy = false
      @search_error = "#{e.class}: #{e.message}"
    end
  end

  def check_notification_api_health
    @notification_api_configured = notification_api_configured?
  end

  def check_giphy_health
    @giphy_configured = giphy_configured?
  end

  def notification_api_configured?
    ENV['NOTIFICATION_API_CLIENT_ID'].present? && ENV['NOTIFICATION_API_CLIENT_SECRET'].present?
  end

  def giphy_configured?
    ENV['GIPHY_API_KEY'].present?
  end
end
