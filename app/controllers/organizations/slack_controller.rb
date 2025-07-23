class Organizations::SlackController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  
  def show
    # The show action displays the Slack integration page for the specific organization
  end
  
  def test_connection
    result = SlackService.new(@organization).test_connection
    if result
      render json: { success: true, team: result['team'], team_id: result['team_id'] }
    else
      render json: { success: false, error: "Connection test failed" }, status: :unprocessable_entity
    end
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
  
  def list_channels
    channels = SlackService.new(@organization).list_channels
    render json: { success: true, channels: channels }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
  
  def post_test_message
    message = params[:message]
    result = SlackService.new(@organization).post_test_message(message)
    render json: result
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
  
  def configuration_status
    config = @organization.slack_config
    render json: {
      configured: config&.configured? || false,
      workspace_name: config&.workspace_name,
      workspace_url: config&.workspace_url,
      default_channel: config&.default_channel,
      bot_username: config&.bot_username,
      bot_emoji: config&.bot_emoji
    }
  end
  
  def update_configuration
    config = @organization.slack_configuration
    
    if config&.update(slack_configuration_params)
      redirect_to organization_slack_path(@organization), notice: 'Slack configuration updated successfully!'
    else
      redirect_to organization_slack_path(@organization), alert: 'Failed to update Slack configuration'
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access Slack integration.'
    end
  end
  
  def slack_configuration_params
    params.require(:slack_configuration).permit(:default_channel, :bot_username, :bot_emoji)
  end
end 