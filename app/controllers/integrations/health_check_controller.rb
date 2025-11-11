class Integrations::HealthCheckController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_authentication

  def index
    # Check NotificationAPI credentials
    @notification_api_configured = notification_api_configured?
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

  private

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access integrations health check.'
    end
  end

  def notification_api_configured?
    ENV['NOTIFICATION_API_CLIENT_ID'].present? && ENV['NOTIFICATION_API_CLIENT_SECRET'].present?
  end
end

