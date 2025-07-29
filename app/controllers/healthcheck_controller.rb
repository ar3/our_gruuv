class HealthcheckController < ApplicationController
  def index
    @rails_env = Rails.env
    @env_vars = ENV.keys.map { |k| "#{k} :: #{ENV[k].size}" }.sort
    
    # Get Rails URL configuration
    @action_mailer_url_options = Rails.application.config.action_mailer.default_url_options
    @action_controller_url_options = Rails.application.config.action_controller.default_url_options
    
    # Test URL generation
    begin
      test_url = Rails.application.routes.url_helpers.root_url
      @test_url_generated = test_url
      @url_generation_works = true
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
