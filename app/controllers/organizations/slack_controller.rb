class Organizations::SlackController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :ensure_company_only
  before_action :authorize_slack_access
  
  def show
    # Load summary data for the page
    @slack_config = @organization.calculated_slack_config
    
    # Teammate association stats
    if @slack_config&.configured?
      begin
        slack_service = SlackService.new(@organization)
        @slack_users = slack_service.list_users
        @total_slack_users = @slack_users.length
      rescue => e
        Rails.logger.error "Slack: Error loading users: #{e.message}"
        @slack_users = []
        @total_slack_users = 0
      end
    else
      @slack_users = []
      @total_slack_users = 0
    end
    
    @total_teammates = @organization.teammates.where(last_terminated_at: nil).count
    @linked_teammates = @organization.teammates
                                     .where(last_terminated_at: nil)
                                     .joins(:teammate_identities)
                                     .where(teammate_identities: { provider: 'slack' })
                                     .distinct
                                     .count
    
    # Channel/Group association stats
    @total_channels = @organization.third_party_objects.slack_channels.count
    @total_groups = @organization.third_party_objects
                                 .where(third_party_source: 'slack', third_party_object_type: 'group')
                                 .count
    
    # Organization summary
    @total_departments = @organization.departments.count
    @total_teams = @organization.teams.count
  end
  
  def test_connection
    result = SlackService.new(@organization).test_connection
    if result.is_a?(Hash)
      status = result['success'] ? :ok : :unprocessable_entity
      render json: result, status: status
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
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access Slack integration.'
    end
  end
  
  def ensure_company_only
    unless @organization.company?
      redirect_to organization_path(@organization), alert: 'Slack configuration is only available for companies.'
    end
  end
  
  def authorize_slack_access
    # Allow if user can manage employment OR is an active company teammate
    unless policy(@organization).manage_employment? || current_company_teammate&.organization == @organization
      redirect_to organization_path(@organization), alert: 'You do not have permission to access Slack configuration.'
    end
  end
  
  def slack_configuration_params
    params.require(:slack_configuration).permit(:default_channel, :bot_username, :bot_emoji)
  end
end 