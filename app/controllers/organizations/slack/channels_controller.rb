class Organizations::Slack::ChannelsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :ensure_company_only
  before_action :authorize_slack_access
  
  def index
    @slack_config = @organization.calculated_slack_config
    
    if @slack_config&.configured?
      slack_service = SlackService.new(@organization)
      @slack_channels = @organization.third_party_objects.slack_channels.order(:display_name)
      @slack_groups = @organization.third_party_objects
                                   .where(third_party_source: 'slack', third_party_object_type: 'group')
                                   .order(:display_name)
    else
      @slack_channels = []
      @slack_groups = []
    end
    
    # Build organization hierarchy (company, departments, teams)
    @organizations = [@organization] + @organization.descendants.to_a.sort_by { |o| [o.type, o.name] }
  end
  
  def refresh_channels
    success = SlackChannelsService.new(@organization).refresh_channels
    
    if success
      redirect_to channels_organization_slack_path(@organization), notice: 'Slack channels refreshed successfully!'
    else
      redirect_to channels_organization_slack_path(@organization), alert: 'Failed to refresh Slack channels. Please check your Slack configuration.'
    end
  end
  
  def refresh_groups
    success = SlackGroupsService.new(@organization).refresh_groups
    
    if success
      redirect_to channels_organization_slack_path(@organization), notice: 'Slack groups refreshed successfully!'
    else
      redirect_to channels_organization_slack_path(@organization), alert: 'Failed to refresh Slack groups. Please check your Slack configuration.'
    end
  end
  
  def update_channel
    org = Organization.find(params[:organization_id])
    channel_id = params[:channel_id]
    
    if org.company?
      company = org.becomes(Company)
      company.huddle_review_notification_channel_id = channel_id
      
      if company.save
        redirect_to channels_organization_slack_path(@organization), notice: 'Channel association updated successfully.'
      else
        redirect_to channels_organization_slack_path(@organization), alert: 'Failed to update channel association.'
      end
    else
      redirect_to channels_organization_slack_path(@organization), alert: 'Huddle review channels can only be set for companies.'
    end
  end
  
  def update_group
    org = Organization.find(params[:organization_id])
    group_id = params[:group_id]
    
    org.slack_group_id = group_id
    
    if org.save
      redirect_to channels_organization_slack_path(@organization), notice: 'Group association updated successfully.'
    else
      redirect_to channels_organization_slack_path(@organization), alert: 'Failed to update group association.'
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
      redirect_to organization_path(@organization), alert: 'Channel associations are only available for companies.'
    end
  end
  
  def authorize_slack_access
    # Allow if user can manage employment OR is an active company teammate
    unless policy(@organization).manage_employment? || current_company_teammate&.organization == @organization
      redirect_to organization_path(@organization), alert: 'You do not have permission to access Slack configuration.'
    end
  end
end

