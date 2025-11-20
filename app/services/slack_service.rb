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
      return { success: false, error: "Notification #{notification_id} not found" }
    end
    return { success: false, error: "Notification is nil" } unless notification.present?
    
    # Extract message data from notification
    channel = notification.metadata['channel']
    raise "Channel is missing from notification #{notification_id}" unless channel.present?
    rich_message = notification.rich_message
    fallback_text = notification.fallback_text
    
    return { success: false, error: "Slack not configured or channel missing" } unless slack_configured? && channel.present?
    
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
      
      { success: true, message_id: response['ts'], channel: channel, response: response }
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error posting message - #{e.message}"
      
      # Update notification with failure
      notification.update!(status: 'send_failed')
      
      # Store the error in debug_responses
      store_slack_response('chat_postMessage', message_params, { error: e.message, backtrace: e.backtrace.first(5) })
      
      { success: false, error: e.message, channel: channel }
    rescue => e
      Rails.logger.error "Slack: Unexpected error posting message - #{e.message}"
      notification.update!(status: 'send_failed')
      { success: false, error: "Unexpected error: #{e.message}", channel: channel }
    end
  end
  
  # Update an existing message using a notification record
  def update_message(notification_id)
    begin
      notification = Notification.find(notification_id)
    rescue ActiveRecord::RecordNotFound
      return { success: false, error: "Notification #{notification_id} not found" }
    end
    return { success: false, error: "Notification is nil" } unless notification.present?
    
    # Get the original message to update
    original_notification = notification.original_message
    return { success: false, error: "Original message not found" } unless original_notification.present? && original_notification.message_id.present?
    
    # Extract message data from notification
    channel = notification.metadata['channel']
    rich_message = notification.rich_message
    fallback_text = notification.fallback_text
    
    return { success: false, error: "Slack not configured or channel missing" } unless slack_configured? && channel.present?
    
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
      
      { success: true, message_id: original_notification.message_id, channel: channel, response: response }
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error updating message - #{e.message}"
      
      # Update notification with failure
      notification.update!(status: 'send_failed')
      
      # Store the error in debug_responses
      store_slack_response('chat_update', message_params, { error: e.message, backtrace: e.backtrace.first(5) })
      
      { success: false, error: e.message, channel: channel }
    rescue => e
      Rails.logger.error "Slack: Unexpected error updating message - #{e.message}"
      notification.update!(status: 'send_failed')
      { success: false, error: "Unexpected error: #{e.message}", channel: channel }
    end
  end
  
  
  
  # Test pagination specifically
  def test_pagination
    return false unless slack_configured?
    
    Rails.logger.info "Slack: Testing pagination for conversations_list"
    
    all_channels = []
    cursor = nil
    page_count = 0
    
    begin
      loop do
        page_count += 1
        params = {
          types: 'public_channel,private_channel,mpim,im,external_shared',
          limit: 1000,
          exclude_archived: true
        }
        params[:cursor] = cursor if cursor
        
        Rails.logger.info "Slack: Page #{page_count} - Fetching with cursor: #{cursor || 'initial'}"
        
        response = @client.conversations_list(params)
        
        # Store the response in debug_responses
        store_slack_response("conversations_list_page_#{page_count}", params, response)
        
        if response['ok'] && response['channels']
          channels = response['channels']
          all_channels.concat(channels)
          Rails.logger.info "Slack: Page #{page_count} - Fetched #{channels.length} channels (total: #{all_channels.length})"
          
          # Check if there are more pages
          cursor = response['response_metadata']&.dig('next_cursor')
          if cursor.present?
            Rails.logger.info "Slack: Page #{page_count} - Has next cursor: #{cursor}"
          else
            Rails.logger.info "Slack: Page #{page_count} - No more pages"
          end
          break unless cursor.present?
        else
          Rails.logger.error "Slack: Page #{page_count} - conversations_list failed: #{response.inspect}"
          break
        end
      end
      
      Rails.logger.info "Slack: Pagination test complete - #{page_count} pages, #{all_channels.length} total channels"
      
      {
        success: true,
        page_count: page_count,
        total_channels: all_channels.length,
        channels: all_channels,
        pagination_worked: page_count > 1 || all_channels.length > 1000
      }
      
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error testing pagination - #{e.message}"
      store_slack_response("conversations_list_pagination_test", { error: true }, { error: e.message, backtrace: e.backtrace.first(5) })
      { success: false, error: e.message }
    end
  end

  # Get comprehensive channel information by type
  def list_all_channel_types
    return [] unless slack_configured?
    
    all_channels = []
    
    # Get public channels
    begin
      Rails.logger.info "Slack: Fetching public channels"
      public_response = @client.conversations_list(types: 'public_channel', limit: 1000, exclude_archived: true)
      if public_response['ok'] && public_response['channels']
        all_channels.concat(public_response['channels'])
        Rails.logger.info "Slack: Found #{public_response['channels'].length} public channels"
      end
      store_slack_response('conversations_list_public', { types: 'public_channel', limit: 1000, exclude_archived: true }, public_response)
    rescue => e
      Rails.logger.error "Slack: Error getting public channels: #{e.message}"
      store_slack_response('conversations_list_public', { types: 'public_channel', limit: 1000, exclude_archived: true }, { error: e.message, backtrace: e.backtrace.first(5) })
    end
    
    # Get private channels
    begin
      Rails.logger.info "Slack: Fetching private channels"
      private_response = @client.conversations_list(types: 'private_channel', limit: 1000, exclude_archived: true)
      if private_response['ok'] && private_response['channels']
        all_channels.concat(private_response['channels'])
        Rails.logger.info "Slack: Found #{private_response['channels'].length} private channels"
      end
      store_slack_response('conversations_list_private', { types: 'private_channel', limit: 1000, exclude_archived: true }, private_response)
    rescue => e
      Rails.logger.error "Slack: Error getting private channels: #{e.message}"
      store_slack_response('conversations_list_private', { types: 'private_channel', limit: 1000, exclude_archived: true }, { error: e.message, backtrace: e.backtrace.first(5) })
    end
    
    # Get MPIMs
    begin
      Rails.logger.info "Slack: Fetching MPIMs"
      mpim_response = @client.conversations_list(types: 'mpim', limit: 1000, exclude_archived: true)
      if mpim_response['ok'] && mpim_response['channels']
        all_channels.concat(mpim_response['channels'])
        Rails.logger.info "Slack: Found #{mpim_response['channels'].length} MPIMs"
      end
      store_slack_response('conversations_list_mpim', { types: 'mpim', limit: 1000, exclude_archived: true }, mpim_response)
    rescue => e
      Rails.logger.error "Slack: Error getting MPIMs: #{e.message}"
      store_slack_response('conversations_list_mpim', { types: 'mpim', limit: 1000, exclude_archived: true }, { error: e.message, backtrace: e.backtrace.first(5) })
    end
    
    # Get DMs
    begin
      Rails.logger.info "Slack: Fetching DMs"
      dm_response = @client.conversations_list(types: 'im', limit: 1000, exclude_archived: true)
      if dm_response['ok'] && dm_response['channels']
        all_channels.concat(dm_response['channels'])
        Rails.logger.info "Slack: Found #{dm_response['channels'].length} DMs"
      end
      store_slack_response('conversations_list_im', { types: 'im', limit: 1000, exclude_archived: true }, dm_response)
    rescue => e
      Rails.logger.error "Slack: Error getting DMs: #{e.message}"
      store_slack_response('conversations_list_im', { types: 'im', limit: 1000, exclude_archived: true }, { error: e.message, backtrace: e.backtrace.first(5) })
    end
    
    # Get external shared channels
    begin
      Rails.logger.info "Slack: Fetching external shared channels"
      external_response = @client.conversations_list(types: 'external_shared', limit: 1000, exclude_archived: true)
      if external_response['ok'] && external_response['channels']
        all_channels.concat(external_response['channels'])
        Rails.logger.info "Slack: Found #{external_response['channels'].length} external shared channels"
      end
      store_slack_response('conversations_list_external', { types: 'external_shared', limit: 1000, exclude_archived: true }, external_response)
    rescue => e
      Rails.logger.error "Slack: Error getting external shared channels: #{e.message}"
      store_slack_response('conversations_list_external', { types: 'external_shared', limit: 1000, exclude_archived: true }, { error: e.message, backtrace: e.backtrace.first(5) })
    end
    
    Rails.logger.info "Slack: Total channels found across all types: #{all_channels.length}"
    all_channels
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
    
    all_channels = []
    cursor = nil
    
    begin
      loop do
        params = {
          types: 'public_channel,private_channel,mpim,im,external_shared',
          limit: 1000,
          exclude_archived: true
        }
        params[:cursor] = cursor if cursor
        
        Rails.logger.info "Slack: Fetching channels with cursor: #{cursor || 'initial'}"
        
        response = @client.conversations_list(params)
        
        # Store the response in debug_responses
        store_slack_response('conversations_list', params, response)
        
        if response['ok'] && response['channels']
          channels = response['channels']
          all_channels.concat(channels)
          Rails.logger.info "Slack: Fetched #{channels.length} channels (total: #{all_channels.length})"
          
          # Check if there are more pages
          cursor = response['response_metadata']&.dig('next_cursor')
          break unless cursor.present?
        else
          Rails.logger.error "Slack: conversations_list failed: #{response.inspect}"
          break
        end
      end
      
      Rails.logger.info "Slack: Total channels found: #{all_channels.length}"
      all_channels
      
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error listing channels - #{e.message}"
      Rails.logger.error "Slack: Error class: #{e.class}"
      Rails.logger.error "Slack: Error code: #{e.code}" if e.respond_to?(:code)
      
      # Store the error in debug_responses
      store_slack_response('conversations_list', { 
        types: 'public_channel,private_channel,mpim,im,external_shared',
        limit: 1000,
        exclude_archived: true,
        error: true
      }, { error: e.message, backtrace: e.backtrace.first(5), code: e.respond_to?(:code) ? e.code : nil })
      
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
  
  # List all users in the workspace
  def list_users
    return [] unless slack_configured?
    
    all_users = []
    cursor = nil
    
    begin
      loop do
        params = { limit: 1000 }
        params[:cursor] = cursor if cursor
        
        Rails.logger.info "Slack: Fetching users with cursor: #{cursor || 'initial'}"
        
        response = @client.users_list(params)
        
        # Store the response in debug_responses
        store_slack_response('users_list', params, response)
        
        if response['ok'] && response['members']
          users = response['members']
          all_users.concat(users)
          Rails.logger.info "Slack: Fetched #{users.length} users (total: #{all_users.length})"
          
          # Check if there are more pages
          cursor = response['response_metadata']&.dig('next_cursor')
          break unless cursor.present?
        else
          Rails.logger.error "Slack: users_list failed: #{response.inspect}"
          break
        end
      end
      
      Rails.logger.info "Slack: Total users found: #{all_users.length}"
      all_users
      
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error listing users - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('users_list', { limit: 1000 }, { error: e.message, backtrace: e.backtrace.first(5) })
      
      []
    end
  end
  
  # List all user groups in the workspace
  def list_groups
    return [] unless slack_configured?
    
    all_groups = []
    cursor = nil
    
    begin
      loop do
        params = { include_users: false }
        params[:cursor] = cursor if cursor
        
        Rails.logger.info "Slack: Fetching groups with cursor: #{cursor || 'initial'}"
        
        response = @client.usergroups_list(params)
        
        # Store the response in debug_responses
        store_slack_response('usergroups_list', params, response)
        
        if response['ok'] && response['usergroups']
          groups = response['usergroups']
          all_groups.concat(groups)
          Rails.logger.info "Slack: Fetched #{groups.length} groups (total: #{all_groups.length})"
          
          # Check if there are more pages
          cursor = response['response_metadata']&.dig('next_cursor')
          break unless cursor.present?
        else
          Rails.logger.error "Slack: usergroups_list failed: #{response.inspect}"
          break
        end
      end
      
      Rails.logger.info "Slack: Total groups found: #{all_groups.length}"
      all_groups
      
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error listing groups - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('usergroups_list', { include_users: false }, { error: e.message, backtrace: e.backtrace.first(5) })
      
      []
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
      if response[:success]
        Rails.logger.info "Slack: Test message posted successfully"
        { success: true, message: "Test message sent successfully" }
      else
        Rails.logger.error "Slack: Failed to post test message - #{response[:error]}"
        { success: false, error: "Failed to post test message: #{response[:error]}" }
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

 