class SlackController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:post_test_message]
  before_action :require_slack_config, only: [:test_connection, :list_channels, :post_test_message]
  
  def index
    # Get all companies (top-level organizations) for Slack configuration
    @organizations = Organization.companies.includes(:slack_configuration)
  end
  
  def test_connection
    organization = find_organization_from_params
    slack_service = SlackService.new(organization)
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
    organization = find_organization_from_params
    slack_service = SlackService.new(organization)
    channels = slack_service.list_channels
    
    render json: { 
      success: true, 
      channels: channels.map { |c| { id: c['id'], name: c['name'], is_private: c['is_private'] } }
    }
  end
  
  def post_test_message
    organization = find_organization_from_params
    channel = params[:channel]
    message = params[:message] || "🧪 Test message from Our Gruuv Huddle Bot!"
    
    slack_service = SlackService.new(organization)
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
    organization = find_organization_from_params
    config = organization&.slack_config
    
    render json: {
      organization_id: organization&.id,
      organization_name: organization&.display_name,
      bot_token_configured: config&.configured? || ENV['SLACK_BOT_TOKEN'].present?,
      workspace_id: config&.workspace_id,
      workspace_name: config&.workspace_name,
      default_channel: config&.default_channel || SlackConstants::DEFAULT_HUDDLE_CHANNEL,
      bot_username: config&.bot_username || SlackConstants::BOT_USERNAME,
      bot_emoji: config&.bot_emoji || SlackConstants::BOT_EMOJI,
      installed_at: config&.installed_at&.iso8601
    }
  end
  
  private
  
  def find_organization_from_params
    organization_id = params[:organization_id]
    Organization.find_by(id: organization_id) if organization_id
  end
  
  def require_slack_config
    organization = find_organization_from_params
    config = organization&.slack_config
    
    unless config&.configured? || ENV['SLACK_BOT_TOKEN'].present?
      render json: { 
        success: false, 
        error: 'Slack not configured for this organization. Please install the Slack app first.' 
      }, status: :unprocessable_entity
      return
    end
  end
end 