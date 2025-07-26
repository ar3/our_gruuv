class SlackService
  include SlackConstants
  
  def self.slack_announcement_url(
    slack_configuration:,
    channel_name:,
    message_id:
  )
    return nil unless slack_configuration.present? && channel_name.present? && message_id.present?
    "#{slack_configuration.workspace_url}/archives/#{channel_name}/p#{message_id.gsub('.', '')}"
  end

  def initialize(organization = nil)
    @organization = organization
    @client = create_client
  end
  
  # Post a message to a Slack channel
  def post_message(channel: nil, text: nil, blocks: nil, **options)
    return false unless slack_configured?
    
    # Use organization-specific defaults if available
    config = @organization&.calculated_slack_config
    default_channel = channel || config&.default_channel_or_general
    bot_username = config&.bot_username_or_default
    bot_emoji = config&.bot_emoji_or_default
    
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
    
    case notification_type
    when :post_summary
      post_huddle_summary(huddle)
    else
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
      
      # Post to the huddle's instruction channel or organization default
      channel = huddle.slack_channel
      
      post_message(channel: channel, text: text)
    end
  end

  # Post huddle start announcement to Slack
  def post_huddle_start_announcement(huddle)
    return false unless huddle.present?
    
    channel = huddle.slack_channel
    return false unless channel.present?
    
    # Create the start announcement blocks
    blocks = build_start_announcement_blocks(huddle)
    
    # Post the announcement
    result = post_message(
      channel: channel,
      blocks: blocks
    )
    
    if result
      huddle.update(announcement_message_id: result['ts'])
    end
    
    result
  end

  # Post or update huddle summary in Slack
  def post_huddle_summary(huddle)
    return false unless huddle.present?
    
    channel = huddle.slack_channel
    return false unless channel.present?
    
    # Create the summary blocks
    blocks = build_summary_blocks(huddle)
    
    if huddle.has_slack_announcement?
      # Update existing announcement
      result = update_message(
        channel: channel,
        ts: huddle.announcement_message_id,
        blocks: blocks
      )
      
      if result
        # Update the summary in the thread
        if huddle.has_slack_summary?
          update_message(
            channel: channel,
            ts: huddle.summary_message_id,
            blocks: build_summary_blocks(huddle, is_thread: true)
          )
        else
          # Create new summary in thread
          thread_result = post_message(
            channel: channel,
            thread_ts: huddle.announcement_message_id,
            blocks: build_summary_blocks(huddle, is_thread: true)
          )
          
          if thread_result
            huddle.update(summary_message_id: thread_result['ts'])
          end
        end
      end
      
      result
    else
      # Create new announcement with summary
      result = post_message(
        channel: channel,
        blocks: blocks
      )
      
      if result
        huddle.update(announcement_message_id: result['ts'])
        
        # Post summary in thread
        thread_result = post_message(
          channel: channel,
          thread_ts: result['ts'],
          blocks: build_summary_blocks(huddle, is_thread: true)
        )
        
        if thread_result
          huddle.update(summary_message_id: thread_result['ts'])
        end
      end
      
      result
    end
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
  
  # Post a test message to the default channel
  def post_test_message(message)
    return { success: false, error: "Slack not configured" } unless slack_configured?
    
    begin
      response = post_message(text: message)
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

  def self.slack_announcement_url(slack_configuration:, channel_name:, message_id:)
    return nil unless slack_configuration&.workspace_subdomain.present? && channel_name.present? && message_id.present?
    
    # Get the workspace URL - this will be nil if we don't have the proper subdomain
    workspace_url = slack_configuration.workspace_url
    return nil unless workspace_url.present?
    
    # Extract channel name (remove the # if present)
    clean_channel_name = channel_name.gsub('#', '')
    
    # Build Slack message URL with proper workspace subdomain
    # Format: https://workspace.slack.com/archives/CHANNEL_ID/p1234567890.123456
    "#{workspace_url}/archives/#{clean_channel_name}/p#{message_id.gsub('.', '')}"
  end
  
  private
  
  def create_client
    if @organization&.slack_configured?
      config = @organization.calculated_slack_config
      Slack::Web::Client.new(token: config.bot_token)
    else
      # Fallback to environment variable for backward compatibility
      ENV['SLACK_BOT_TOKEN'].present? ? SLACK_CLIENT : nil
    end
  end
  
  def slack_configured?
    @organization&.slack_configured? || ENV['SLACK_BOT_TOKEN'].present?
  end

  def generate_notification_preview(huddle)
    {
      main_announcement: build_summary_blocks(huddle, is_thread: false),
      detailed_summary: build_summary_blocks(huddle, is_thread: true),
      channel: huddle.slack_channel,
      organization_name: huddle.organization.display_name
    }
  end

  def build_start_announcement_blocks(huddle)
    [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "🚀 #{huddle.display_name} - Starting Now!",
          emoji: true
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "The huddle is starting! Join in to participate in today's collaborative session."
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: "👥 #{huddle.huddle_participants.count} participants • Facilitated by #{huddle.facilitator_names.join(', ')}"
          }
        ]
      }
    ]
  end

  def build_summary_blocks(huddle, is_thread: false)
    if is_thread
      # Detailed summary for thread
      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "📊 Huddle Summary",
            emoji: true
          }
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Participation:*\n#{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants"
            },
            {
              type: "mrkdwn",
              text: "*Nat 20 Score:*\n#{huddle.nat_20_score || 'N/A'}"
            }
          ]
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Average Ratings:*\n• Informed: #{huddle.average_rating_by_category[:informed] || 'N/A'}/5\n• Connected: #{huddle.average_rating_by_category[:connected] || 'N/A'}/5\n• Goals: #{huddle.average_rating_by_category[:goals] || 'N/A'}/5\n• Valuable: #{huddle.average_rating_by_category[:valuable] || 'N/A'}/5"
            },
            {
              type: "mrkdwn",
              text: "*Insights:*\n#{huddle.feedback_insights.first(2).join("\n") || 'No insights yet'}"
            }
          ]
        }
      ]
    else
      # Main announcement
      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🎯 #{huddle.display_name} - Summary Available",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "The huddle summary is now available! Check the thread below for detailed insights and feedback highlights."
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "📈 #{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants submitted feedback • Nat 20 Score: #{huddle.nat_20_score || 'N/A'}"
            }
          ]
        }
      ]
    end
  end
end 