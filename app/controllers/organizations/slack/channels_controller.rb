class Organizations::Slack::ChannelsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :authorize_slack_access
  before_action :load_slack_data, only: [:index, :edit, :edit_company, :edit_team]
  before_action :load_target_organization, only: [:edit, :update, :edit_company, :update_company]
  before_action :ensure_company_target, only: [:edit_company, :update_company]
  before_action :load_team, only: [:edit_team, :update_team]
  before_action :set_teammates_with_manage_employment, only: [:index, :edit, :edit_company, :edit_team]

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

  def edit_team
    # Uses @team and @slack_channels from before_actions
  end

  def update_team
    channel_id = params.require(:team).permit(:huddle_channel_id)[:huddle_channel_id]
    @team.huddle_channel_id = channel_id.presence
    redirect_to channels_organization_slack_path(@organization), notice: 'Team huddle channel updated successfully.'
  rescue StandardError
    load_slack_data
    load_team
    flash.now[:alert] = 'Unable to update team huddle channel.'
    render :edit_team, status: :unprocessable_entity
  end

  def edit_company
    # Uses @target_organization and @slack_channels from before_actions
  end

  def update_company
    attrs = params.require(:organization).permit(:huddle_review_channel_id, :maap_object_comment_channel_id, :kudos_channel_id)

    @target_organization.huddle_review_notification_channel_id = attrs[:huddle_review_channel_id].presence if attrs.key?(:huddle_review_channel_id)
    @target_organization.maap_object_comment_channel_id = attrs[:maap_object_comment_channel_id].presence if attrs.key?(:maap_object_comment_channel_id)
    @target_organization.kudos_channel_id = attrs[:kudos_channel_id].presence if attrs.key?(:kudos_channel_id)
    @target_organization.save!

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

  def authorize_slack_access
    if %w[index edit edit_company edit_team].include?(action_name)
      unless policy(@organization).view_slack_settings?
        redirect_to organization_path(@organization), alert: 'You do not have permission to access Slack configuration.'
      end
    else
      unless policy(@organization).manage_employment?
        redirect_to organization_path(@organization), alert: 'You do not have permission to modify Slack channel settings.'
      end
    end
  end

  def set_teammates_with_manage_employment
    @teammates_with_manage_employment = @organization.teammates
      .where(last_terminated_at: nil)
      .where(can_manage_employment: true)
      .includes(:person)
      .map { |t| t.person&.casual_name }
      .compact
      .sort
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

    # Build list: company plus its departments (for kudos/slack group per org)
    @organizations = [@organization] + @organization.departments.active.ordered.to_a

    # Load teams for huddle channel configuration
    @teams = @organization.teams.active.ordered
  end

  def load_target_organization
    target_id = params[:target_organization_id].to_i
    allowed_ids = [@organization.id] + @organization.departments.pluck(:id)

    unless allowed_ids.include?(target_id)
      redirect_to channels_organization_slack_path(@organization), alert: 'Organization not found.' and return
    end

    # Company-only actions must resolve to the organization only (avoid Department id collision)
    if %w[edit_company update_company].include?(action_name)
      if target_id != @organization.id
        redirect_to channels_organization_slack_path(@organization), alert: 'Organization not found.' and return
      end
      @target_organization = @organization
      return
    end

    # Prefer department when target_id is a department of this org (ids can overlap across tables)
    @target_organization = Department.find_by(id: target_id, company: @organization) || Organization.find_by(id: target_id)
    unless @target_organization
      redirect_to channels_organization_slack_path(@organization), alert: 'Organization not found.' and return
    end
  end

  # Company-only channel settings (huddle review, comment channel) apply only to the root organization, not departments.
  def ensure_company_target
    return if @target_organization == @organization

    redirect_to channels_organization_slack_path(@organization), alert: 'Company channel settings apply only to the organization, not departments.'
  end

  def load_team
    team_id = params[:team_id].to_i
    @team = @organization.teams.find_by(id: team_id)
    unless @team
      redirect_to channels_organization_slack_path(@organization), alert: 'Team not found.' and return
    end
  end
end

