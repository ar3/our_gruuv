class HealthcheckController < ApplicationController
  def index
    @rails_env = Rails.env
    @env_vars = ENV.keys.map { |k| "#{k} :: #{ENV[k].size}" }.sort
    
    begin
      @person_count = Person.count
      @db_status = "Connected"
      @db_error = nil
    rescue => e
      @person_count = "ERROR"
      @db_status = "Failed"
      @db_error = "#{e.class}: #{e.message}"
    end
  end
end
