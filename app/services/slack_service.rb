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
      
      # Store the response in debug_responses
      store_slack_response('chat_postMessage', message_params, response)
      
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error posting message - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('chat_postMessage', message_params, { error: e.message, backtrace: e.backtrace.first(5) })
      
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
      
      # Store the response in debug_responses
      store_slack_response('chat_update', message_params, response)
      
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Slack: Error updating message - #{e.message}"
      
      # Store the error in debug_responses
      store_slack_response('chat_update', message_params, { error: e.message, backtrace: e.backtrace.first(5) })
      
      false
    end
  end
  
  # Post a huddle notification
  def post_huddle_notification(huddle, notification_type, **options)
    return false unless huddle.present?
    
    case notification_type
    when :post_summary
      post_huddle_summary(huddle)
    when :post_feedback_in_thread
      post_feedback_in_thread(huddle, options[:feedback_id])
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
      
      post_message(
        channel: channel, 
        text: text)
    end
  end

  # Post huddle start announcement to Slack
  def post_huddle_start_announcement(huddle)
    return false unless huddle.present?
    
    channel = huddle.slack_channel
    return false unless channel.present?
    
    # Create notification record
    notification = huddle.notifications.create!(
      notification_type: 'huddle_announcement',
      status: 'preparing_to_send',
      metadata: { channel: channel },
      message: build_start_announcement_blocks(huddle)
    )
    
    # Post the announcement
    result = post_message(
      channel: channel,
      blocks: notification.message
    )
    
    if result
      notification.update!(
        status: 'sent_successfully',
        message_id: result['ts']
      )
    else
      notification.update!(status: 'send_failed')
    end
    
    result
  end

  # Post or update huddle summary in Slack
  def post_huddle_summary(huddle)
    return false unless huddle.present?
    
    channel = huddle.slack_channel
    return false unless channel.present?
    
    # Check if huddle has an announcement notification
    announcement_notification = huddle.slack_announcement_notification
    
    if announcement_notification.nil?
      # Create announcement first
      post_huddle_start_announcement(huddle)
      announcement_notification = huddle.slack_announcement_notification
    end
    
    # Check if summary already exists
    existing_summary = huddle.notifications.summaries.successful.first
    
    if existing_summary
      # Update existing summary
      existing_summary.update!(
        status: 'preparing_to_send',
        message: build_summary_blocks(huddle, is_thread: true)
      )
      
      result = update_message(
        channel: channel,
        ts: existing_summary.message_id,
        blocks: existing_summary.message
      )
      
      if result
        existing_summary.update!(status: 'sent_successfully')
      else
        existing_summary.update!(status: 'send_failed')
      end
      
      result
    else
      # Create new summary notification
      summary_notification = huddle.notifications.create!(
        notification_type: 'huddle_summary',
        main_thread: announcement_notification,
        status: 'preparing_to_send',
        metadata: { channel: channel },
        message: build_summary_blocks(huddle, is_thread: true)
      )
      
      # Post summary in thread
      result = post_message(
        channel: channel,
        thread_ts: announcement_notification.message_id,
        blocks: summary_notification.message
      )
      
      if result
        summary_notification.update!(
          status: 'sent_successfully',
          message_id: result['ts']
        )
      else
        summary_notification.update!(status: 'send_failed')
      end
      
      result
    end
  end

  # Post individual feedback in the announcement thread
  def post_feedback_in_thread(huddle, feedback_id)
    return false unless huddle.present?
    
    feedback = huddle.huddle_feedbacks.find_by(id: feedback_id)
    return false unless feedback.present?
    
    channel = huddle.slack_channel
    return false unless channel.present?
    
    # Check if huddle has an announcement notification
    announcement_notification = huddle.slack_announcement_notification
    
    if announcement_notification.nil?
      # Create announcement and summary first
      post_huddle_start_announcement(huddle)
      post_huddle_summary(huddle)
      announcement_notification = huddle.slack_announcement_notification
    end
    
    # Create feedback notification record
    feedback_notification = huddle.notifications.create!(
      notification_type: 'huddle_feedback',
      main_thread: announcement_notification,
      status: 'preparing_to_send',
      metadata: { channel: channel },
      message: build_feedback_blocks(feedback)
    )
    
    # Post in the announcement thread
    result = post_message(
      channel: channel,
      thread_ts: announcement_notification.message_id,
      blocks: feedback_notification.message
    )
    
    if result
      feedback_notification.update!(
        status: 'sent_successfully',
        message_id: result['ts']
      )
    else
      feedback_notification.update!(status: 'send_failed')
    end
    
    result
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

  def build_feedback_blocks(feedback)
    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "💬 *New Feedback from #{feedback.display_name}*"
        }
      },
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*Nat 20 Score:* #{feedback.nat_20_score}/20"
          },
          {
            type: "mrkdwn",
            text: "*Ratings:* I:#{feedback.informed_rating} C:#{feedback.connected_rating} G:#{feedback.goals_rating} V:#{feedback.valuable_rating}"
          }
        ]
      }
    ].tap do |blocks|
      # Add appreciation if present
      if feedback.appreciation.present?
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Appreciation:* #{feedback.appreciation}"
          }
        }
      end

      # Add change suggestion if present
      if feedback.change_suggestion.present?
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Change Suggestion:* #{feedback.change_suggestion}"
          }
        }
      end

      # Add conflict styles if present
      if feedback.personal_conflict_style.present? || feedback.team_conflict_style.present?
        conflict_text = []
        conflict_text << "Personal: #{feedback.personal_conflict_style}" if feedback.personal_conflict_style.present?
        conflict_text << "Team: #{feedback.team_conflict_style}" if feedback.team_conflict_style.present?
        
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Conflict Styles:* #{conflict_text.join(' • ')}"
          }
        }
      end
    end
  end
end

 