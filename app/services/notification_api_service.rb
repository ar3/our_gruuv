class NotificationApiService
  BASE_URL = 'https://api.notificationapi.com'
  
  # Note: NotificationAPI's Node.js SDK uses init(client_id, client_secret) and handles
  # authentication internally. The REST API endpoint appears to require AWS SigV4,
  # but client_id/client_secret are not AWS credentials. The SDK likely:
  # 1. Uses a different endpoint/backend
  # 2. Exchanges client_id/client_secret for AWS credentials
  # 3. Or uses a custom authentication layer
  
  def initialize(client_id:, client_secret:)
    @client_id = client_id
    @client_secret = client_secret
  end

  # Test the connection by sending a test notification
  # Optional parameters allow customizing the test notification
  def test_connection(type: 'initial_test', to: { id: 'ar3@ar3.me', number: '+13172898859' }, sms: { message: 'Hello, world!' })
    # The endpoint includes the client_id in the path: /{client_id}/sender
    url = "#{BASE_URL}/#{@client_id}/sender"
    
    body = {
      type: type,
      to: to,
      sms: sms
    }.to_json
    
    # Try Basic Auth (matching Node.js SDK approach)
    # The Node.js SDK uses init(client_id, client_secret) which suggests Basic Auth
    Rails.logger.debug "NotificationAPI: Making request to #{url} with Basic Auth"
    
    response = HTTP.basic_auth(user: @client_id, pass: @client_secret)
                   .headers('Content-Type' => 'application/json')
                   .post(url, body: body)

    if response.status == 200 || response.status == 201
      Rails.logger.info "NotificationAPI: Connection test successful"
      JSON.parse(response.body.to_s)
    else
      error_body = response.body.to_s
      Rails.logger.error "NotificationAPI: Connection test failed - #{response.status}: #{error_body}"
      
      # Parse the error response from NotificationAPI
      original_error = error_body
      our_note = nil
      
      # Add helpful context for common authentication errors
      if error_body.include?('UnrecognizedClientException') || error_body.include?('invalid')
        our_note = "NOTE: This error suggests the authentication method may be incorrect. " \
                   "NotificationAPI's Node.js SDK uses init(client_id, client_secret), but the REST API " \
                   "may require a different authentication method. Please check NotificationAPI documentation " \
                   "or contact support for REST API authentication guidance."
      elsif error_body.include?('IncompleteSignatureException') || error_body.include?('Signature')
        our_note = "NOTE: This error suggests AWS SigV4 authentication is required. " \
                   "The Node.js SDK may handle this internally. You may need to use AWS SigV4 signing " \
                   "with proper AWS credentials (not client_id/client_secret)."
      end
      
      { 
        success: false, 
        status: response.status, 
        error: original_error,  # Original error from NotificationAPI
        note: our_note,  # Our helpful note (separate field)
        headers: response.headers.to_h
      }
    end
  rescue => e
    Rails.logger.error "NotificationAPI: Connection test error - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { 
      success: false, 
      error: e.message,
      backtrace: e.backtrace.first(5)
    }
  end

  # Send a notification with channel-specific parameters
  # Example:
  #   service.send_notification(
  #     type: 'initial_test',
  #     to: { id: 'user@example.com', number: '+1234567890' },
  #     sms: { message: 'Hello!' },
  #     email: { subject: 'Test', body: 'Test email' }
  #   )
  def send_notification(type:, to:, **channel_params)
    payload = {
      type: type,
      to: to
    }
    
    # Add channel-specific parameters (sms, email, push, etc.)
    channel_params.each do |channel, params|
      payload[channel] = params if params.present?
    end

    # The endpoint includes the client_id in the path: /{client_id}/sender
    url = "#{BASE_URL}/#{@client_id}/sender"
    body = payload.to_json
    
    # Use Basic Auth (matching Node.js SDK and curl examples)
    Rails.logger.debug "NotificationAPI: Making request to #{url} with Basic Auth"
    
    response = HTTP.basic_auth(user: @client_id, pass: @client_secret)
                   .headers('Content-Type' => 'application/json')
                   .post(url, body: body)

    if response.status == 200 || response.status == 201
      Rails.logger.info "NotificationAPI: Notification sent successfully"
      { success: true, response: JSON.parse(response.body.to_s) }
    else
      Rails.logger.error "NotificationAPI: Failed to send notification - #{response.status}: #{response.body.to_s}"
      { success: false, error: "HTTP #{response.status}: #{response.body.to_s}" }
    end
  rescue => e
    Rails.logger.error "NotificationAPI: Error sending notification - #{e.message}"
    { success: false, error: e.message }
  end
end

