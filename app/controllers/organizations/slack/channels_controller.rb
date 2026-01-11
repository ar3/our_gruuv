class Organizations::Slack::ChannelsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :ensure_company_only
  before_action :authorize_slack_access
  before_action :load_slack_data, only: [:index, :edit, :edit_company]
  before_action :load_target_organization, only: [:edit, :update, :edit_company, :update_company]
  
  def index
    # Show-only page listing current settings and edit links
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
  
  def edit
    # Uses @target_organization and @slack_channels/@slack_groups from before_actions
  end

  def update
    attrs = params.require(:organization).permit(:kudos_channel_id, :slack_group_id)

    # Update kudos and group associations
    if attrs.key?(:kudos_channel_id)
      @target_organization.kudos_channel_id = attrs[:kudos_channel_id].presence
    end

    if attrs.key?(:slack_group_id)
      @target_organization.slack_group_id = attrs[:slack_group_id].presence
    end

    redirect_to channels_organization_slack_path(@organization), notice: 'Channel settings updated successfully.'
  rescue StandardError
    load_slack_data
    flash.now[:alert] = 'Unable to update channel settings.'
    render :edit, status: :unprocessable_entity
  end

  def edit_company
    unless @target_organization.company?
      redirect_to channels_organization_slack_path(@organization), alert: 'Company-only settings are only available for companies.' and return
    end
    # Uses @target_organization and @slack_channels from before_actions
  end

  def update_company
    unless @target_organization.company?
      redirect_to channels_organization_slack_path(@organization), alert: 'Company-only settings are only available for companies.' and return
    end

    attrs = params.require(:organization).permit(:huddle_review_channel_id, :maap_object_comment_channel_id)

    company = Company.find(@target_organization.id)
    company.huddle_review_notification_channel_id = attrs[:huddle_review_channel_id].presence if attrs.key?(:huddle_review_channel_id)
    company.maap_object_comment_channel_id = attrs[:maap_object_comment_channel_id].presence if attrs.key?(:maap_object_comment_channel_id)
    company.save!

    redirect_to channels_organization_slack_path(@organization), notice: 'Company-only channels updated successfully.'
  rescue StandardError => e
    load_slack_data
    flash.now[:alert] = 'Unable to update company-only channel settings.'
    render :edit_company, status: :unprocessable_entity
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

  def load_slack_data
    @slack_config = @organization.calculated_slack_config

    if @slack_config&.configured?
      SlackService.new(@organization) # ensure any side-effects are preserved
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

  def load_target_organization
    target_id = params[:target_organization_id].to_i
    allowed_ids = [@organization.id] + @organization.descendants.pluck(:id)

    unless allowed_ids.include?(target_id)
      redirect_to channels_organization_slack_path(@organization), alert: 'Organization not found.' and return
    end

    @target_organization = Organization.find_by(id: target_id)
    unless @target_organization
      redirect_to channels_organization_slack_path(@organization), alert: 'Organization not found.' and return
    end
  end
end

