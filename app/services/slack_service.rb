class SlackService
  include SlackConstants
  


  def initialize(organization = nil)
    @organization = organization
    @config = @organization&.calculated_slack_config
    raise "Slack configuration is missing for organization #{@organization.id}" unless @config.present?
    @client = create_client
  end
  
  # Post a message to Slack using a notification record
  def post_message(notification_id)
    begin
      notification = Notification.find(notification_id)
    rescue ActiveRecord::RecordNotFound
      return false
    end
    return false unless notification.present?
    
    # Extract message data from notification
    channel = notification.metadata['channel']
    raise "Channel is missing from notification #{notification_id}" unless channel.present?
    rich_message = notification.rich_message
    fallback_text = notification.fallback_text
    
    return false unless slack_configured? && channel.present?
    
    # Use organization-specific defaults if available
    
    bot_username = @config&.bot_username_or_default
    bot_emoji = @config&.bot_emoji_or_default
    
    message_params = {
      channel: channel,
      username: bot_username,
      icon_emoji: bot_emoji,
      text: fallback_text,
      blocks: rich_message
    }
    
    # Add thread_ts if this is a thread reply
    if notification.main_thread.present? && notification.main_thread.message_id.present?
      message_params[:thread_ts] = notification.main_thread.message_id
    end
    
    Rails.logger.info "Slack: Posting message to #{channel}"
    
    begin
      response = @client.chat_postMessage(message_params)
      Rails.logger.info "Slack: Message posted successfully - #{response['ts']}"
      
      # Update notification with success
      notification.update!(
        status: 'sent_successfully',
        message_id: response['ts']
      )
      
      # Store the response in debug_responses
      store_slack_response('chat_postMessage', message_params, response)
      
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error posting message - #{e.message}"
      
      # Update notification with failure
      notification.update!(status: 'send_failed')
      
      # Store the error in debug_responses
      store_slack_response('chat_postMessage', message_params, { error: e.message, backtrace: e.backtrace.first(5) })
      
      false
    end
  end
  
  # Update an existing message using a notification record
  def update_message(notification_id)
    begin
      notification = Notification.find(notification_id)
    rescue ActiveRecord::RecordNotFound
      return false
    end
    return false unless notification.present?
    
    # Get the original message to update
    original_notification = notification.original_message
    return false unless original_notification.present? && original_notification.message_id.present?
    
    # Extract message data from notification
    channel = notification.metadata['channel']
    rich_message = notification.rich_message
    fallback_text = notification.fallback_text
    
    return false unless slack_configured? && channel.present?
    
    message_params = {
      channel: channel,
      ts: original_notification.message_id,
      text: fallback_text,
      blocks: rich_message
    }
    
    Rails.logger.info "Slack: Updating message #{original_notification.message_id} in #{channel}"
    
    begin
      response = @client.chat_update(message_params)
      Rails.logger.info "Slack: Message updated successfully"
      
      # Update notification with success
      notification.update!(
        status: 'sent_successfully',
        message_id: original_notification.message_id
      )
      
      # Store the response in debug_responses
      store_slack_response('chat_update', message_params, response)
      
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error updating message - #{e.message}"
      
      # Update notification with failure
      notification.update!(status: 'send_failed')
      
      # Store the error in debug_responses
      store_slack_response('chat_update', message_params, { error: e.message, backtrace: e.backtrace.first(5) })
      
      false
    end
  end
  
  
  
  # Get channel information
  def get_channel_info(channel_id)
    return false unless slack_configured?
    
    begin
      response = @client.conversations_info(channel: channel_id)
      
      # Store the response in debug_responses
      store_slack_response('conversations_info', { channel: channel_id }, response)
      
      response['channel']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error getting channel info - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('conversations_info', { channel: channel_id }, { error: e.message, backtrace: e.backtrace.first(5) })
      
      false
    end
  end
  
  # List all channels the bot has access to
  def list_channels
    return [] unless slack_configured?
    
    begin
      response = @client.conversations_list(types: 'public_channel,private_channel')
      
      # Store the response in debug_responses
      store_slack_response('conversations_list', { types: 'public_channel,private_channel' }, response)
      
      response['channels']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error listing channels - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('conversations_list', { types: 'public_channel,private_channel' }, { error: e.message, backtrace: e.backtrace.first(5) })
      
      []
    end
  end
  
  # Get user information
  def get_user_info(user_id)
    return false unless slack_configured?
    
    begin
      response = @client.users_info(user: user_id)
      
      # Store the response in debug_responses
      store_slack_response('users_info', { user: user_id }, response)
      
      response['user']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error getting user info - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('users_info', { user: user_id }, { error: e.message, backtrace: e.backtrace.first(5) })
      
      false
    end
  end
  
  # Test the Slack connection
  def test_connection
    return false unless slack_configured?
    
    begin
      response = @client.auth_test
      Rails.logger.info "Slack: Connection test successful - #{response['team']} (#{response['team_id']})"
      
      # Store the response in debug_responses
      store_slack_response('auth_test', {}, response)
      
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Connection test failed - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('auth_test', {}, { error: e.message, backtrace: e.backtrace.first(5) })
      
      false
    end
  end
  
  # Post a test message to the default channel
  def post_test_message(message)
    return { success: false, error: "Slack not configured" } unless slack_configured?
    
    # Create a test notification
    test_notification = Notification.create!(
      notifiable: @organization,
      notification_type: 'test',
      status: 'preparing_to_send',
      metadata: { channel: @organization&.calculated_slack_config&.default_channel_or_general || '#general' },
      rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: message } }],
      fallback_text: message
    )
    
    begin
      response = post_message(test_notification.id)
      if response
        Rails.logger.info "Slack: Test message posted successfully"
        { success: true, message: "Test message sent successfully" }
      else
        Rails.logger.error "Slack: Failed to post test message"
        { success: false, error: "Failed to post test message" }
      end
    rescue => e
      Rails.logger.error "Slack: Error posting test message - #{e.message}"
      { success: false, error: e.message }
    end
  end



  def store_slack_response(method, request_params, response_data)
    return unless @organization&.slack_configuration.present?
    
    begin
      DebugResponse.create!(
        responseable: @organization.slack_configuration,
        request: {
          method: method,
          params: request_params
        },
        response: response_data,
        notes: "Slack API #{method} response"
      )
    rescue => e
      Rails.logger.error "Failed to store Slack response in debug_responses: #{e.message}"
    end
  end
  
  def slack_configured?
    @organization&.slack_configured? || ENV['SLACK_BOT_TOKEN'].present?
  end
  
  private
  

  
  def create_client
    if @organization&.slack_configured?
      Slack::Web::Client.new(token: @config.bot_token)
    else
      # Fallback to environment variable for backward compatibility
      ENV['SLACK_BOT_TOKEN'].present? ? SLACK_CLIENT : nil
    end
  end


end

 