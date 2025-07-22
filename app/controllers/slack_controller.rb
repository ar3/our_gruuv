class SlackController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:post_test_message]
  before_action :require_slack_config, only: [:test_connection, :list_channels, :post_test_message]
  
  def test_connection
    slack_service = SlackService.new
    result = slack_service.test_connection
    
    if result
      render json: { 
        success: true, 
        team: result['team'], 
        team_id: result['team_id'],
        user_id: result['user_id'],
        user: result['user']
      }
    else
      render json: { success: false, error: 'Failed to connect to Slack' }, status: :unprocessable_entity
    end
  end
  
  def list_channels
    slack_service = SlackService.new
    channels = slack_service.list_channels
    
    render json: { 
      success: true, 
      channels: channels.map { |c| { id: c['id'], name: c['name'], is_private: c['is_private'] } }
    }
  end
  
  def post_test_message
    channel = params[:channel] || SlackConstants::DEFAULT_HUDDLE_CHANNEL
    message = params[:message] || "🧪 Test message from Our Gruuv Huddle Bot!"
    
    slack_service = SlackService.new
    result = slack_service.post_message(
      channel: channel,
      text: message
    )
    
    if result
      render json: { 
        success: true, 
        message: 'Test message posted successfully',
        timestamp: result['ts'],
        channel: result['channel']
      }
    else
      render json: { success: false, error: 'Failed to post test message' }, status: :unprocessable_entity
    end
  end
  
  def configuration_status
    render json: {
      bot_token_configured: ENV['SLACK_BOT_TOKEN'].present?,
      default_channel: SlackConstants::DEFAULT_HUDDLE_CHANNEL,
      bot_username: SlackConstants::BOT_USERNAME,
      bot_emoji: SlackConstants::BOT_EMOJI
    }
  end
  
  private
  
  def require_slack_config
    unless ENV['SLACK_BOT_TOKEN'].present?
      render json: { 
        success: false, 
        error: 'Slack bot token not configured. Please set SLACK_BOT_TOKEN environment variable.' 
      }, status: :unprocessable_entity
      return
    end
  end
end 