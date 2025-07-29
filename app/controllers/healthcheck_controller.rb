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
end
