class SlackService
  include SlackConstants
  
  def initialize(organization = nil)
    @organization = organization
    @client = create_client
  end
  
  # Post a message to a Slack channel
  def post_message(channel: nil, text: nil, blocks: nil, **options)
    return false unless slack_configured?
    
    # Use organization-specific defaults if available
    config = @organization&.slack_config
    default_channel = channel || config&.default_channel || DEFAULT_HUDDLE_CHANNEL
    bot_username = config&.bot_username || BOT_USERNAME
    bot_emoji = config&.bot_emoji || BOT_EMOJI
    
    message_params = {
      channel: default_channel,
      username: bot_username,
      icon_emoji: bot_emoji
    }.merge(options)
    
    message_params[:text] = text if text.present?
    message_params[:blocks] = blocks if blocks.present?
    
    Rails.logger.info "Slack: Posting message to #{default_channel}"
    
    begin
      response = @client.chat_postMessage(message_params)
      Rails.logger.info "Slack: Message posted successfully - #{response['ts']}"
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error posting message - #{e.message}"
      false
    end
  end
  
  # Update an existing message
  def update_message(channel:, ts:, text: nil, blocks: nil, **options)
    return false unless slack_configured?
    
    message_params = {
      channel: channel,
      ts: ts
    }.merge(options)
    
    message_params[:text] = text if text.present?
    message_params[:blocks] = blocks if blocks.present?
    
    Rails.logger.info "Slack: Updating message #{ts} in #{channel}"
    
    begin
      response = @client.chat_update(message_params)
      Rails.logger.info "Slack: Message updated successfully"
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error updating message - #{e.message}"
      false
    end
  end
  
  # Post a huddle notification
  def post_huddle_notification(huddle, notification_type, **options)
    return false unless huddle.present?
    
    template = MESSAGE_TEMPLATES[notification_type]
    return false unless template.present?
    
    # Build message data
    message_data = {
      huddle_name: huddle.display_name,
      creator_name: huddle.facilitator_names.join(', '),
      participation_rate: huddle.participation_rate,
      nat_20_score: huddle.nat_20_score
    }.merge(options)
    
    # Format the message
    text = template % message_data
    
    # Post to the huddle's specific channel or organization default
    config = @organization&.slack_config
    channel = huddle.slack_channel || config&.default_channel || DEFAULT_HUDDLE_CHANNEL
    
    post_message(channel: channel, text: text)
  end
  
  # Get channel information
  def get_channel_info(channel_id)
    return false unless slack_configured?
    
    begin
      response = @client.conversations_info(channel: channel_id)
      response['channel']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error getting channel info - #{e.message}"
      false
    end
  end
  
  # List all channels the bot has access to
  def list_channels
    return [] unless slack_configured?
    
    begin
      response = @client.conversations_list(types: 'public_channel,private_channel')
      response['channels']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error listing channels - #{e.message}"
      []
    end
  end
  
  # Get user information
  def get_user_info(user_id)
    return false unless slack_configured?
    
    begin
      response = @client.users_info(user: user_id)
      response['user']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error getting user info - #{e.message}"
      false
    end
  end
  
  # Test the Slack connection
  def test_connection
    return false unless slack_configured?
    
    begin
      response = @client.auth_test
      Rails.logger.info "Slack: Connection test successful - #{response['team']} (#{response['team_id']})"
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Connection test failed - #{e.message}"
      false
    end
  end
  
  private
  
  def create_client
    if @organization&.slack_configured?
      config = @organization.slack_config
      Slack::Web::Client.new(token: config.bot_token)
    else
      # Fallback to environment variable for backward compatibility
      ENV['SLACK_BOT_TOKEN'].present? ? SLACK_CLIENT : nil
    end
  end
  
  def slack_configured?
    @organization&.slack_configured? || ENV['SLACK_BOT_TOKEN'].present?
  end
end 