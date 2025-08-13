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
  
  def debug_channels
    slack_service = SlackService.new(@organization)
    
    # Get raw API response for debugging
    begin
      response = slack_service.instance_variable_get(:@client).conversations_list(
        types: 'public_channel,private_channel,mpim,im,external_shared',
        limit: 1000,
        exclude_archived: true
      )
      
      render json: {
        success: true,
        response_metadata: response['response_metadata'],
        total_channels: response['channels']&.length || 0,
        has_more: response['response_metadata']&.dig('next_cursor').present?,
        next_cursor: response['response_metadata']&.dig('next_cursor'),
        sample_channels: response['channels']&.first(5),
        full_response: response
      }
    rescue => e
      render json: { success: false, error: e.message }
    end
  end
  
  def list_all_channel_types
    channels = SlackService.new(@organization).list_all_channel_types
    render json: { success: true, channels: channels, count: channels.length }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
  
  def debug_responses
    @debug_responses = @organization.slack_configuration&.debug_responses&.order(created_at: :desc)&.limit(50)
    render json: @debug_responses.map { |dr| {
      id: dr.id,
      method: dr.request['method'],
      params: dr.request['params'],
      response: dr.response,
      notes: dr.notes,
      created_at: dr.created_at
    }}
  end
  
  def test_pagination
    result = SlackService.new(@organization).test_pagination
    render json: result
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