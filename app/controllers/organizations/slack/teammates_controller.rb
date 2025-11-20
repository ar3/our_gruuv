class Organizations::Slack::TeammatesController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :ensure_company_only
  before_action :authorize_slack_access
  
  def index
    @slack_config = @organization.calculated_slack_config
    
    if @slack_config&.configured?
      begin
        slack_service = SlackService.new(@organization)
        @slack_users = slack_service.list_users
      rescue => e
        Rails.logger.error "Slack: Error loading users: #{e.message}"
        @slack_users = []
      end
    else
      @slack_users = []
    end
    
    @teammates = @organization.teammates
                             .where(last_terminated_at: nil)
                             .includes(:person, :teammate_identities)
                             .order('people.last_name, people.first_name')
  end
  
  def update
    teammate = @organization.teammates.find(params[:teammate_id])
    slack_user_id = params[:slack_user_id]
    
    if slack_user_id.present?
      # Find the Slack user data
      slack_service = SlackService.new(@organization)
      slack_users = slack_service.list_users
      slack_user = slack_users.find { |u| u['id'] == slack_user_id }
      
      if slack_user
        # Create or update the identity
        identity = teammate.teammate_identities.find_or_initialize_by(provider: 'slack')
        identity.uid = slack_user_id
        identity.email = slack_user.dig('profile', 'email')
        identity.name = slack_user.dig('profile', 'real_name') || slack_user.dig('profile', 'display_name') || slack_user['name']
        identity.profile_image_url = slack_user.dig('profile', 'image_512') || 
                                     slack_user.dig('profile', 'image_192') ||
                                     slack_user.dig('profile', 'image_72')
        identity.raw_data = slack_user
        
        if identity.save
          redirect_to teammates_organization_slack_path(@organization), notice: 'Teammate association updated successfully.'
        else
          redirect_to teammates_organization_slack_path(@organization), alert: "Failed to update association: #{identity.errors.full_messages.join(', ')}"
        end
      else
        redirect_to teammates_organization_slack_path(@organization), alert: 'Slack user not found.'
      end
    else
      # Remove the association
      teammate.teammate_identities.where(provider: 'slack').destroy_all
      redirect_to teammates_organization_slack_path(@organization), notice: 'Teammate association removed.'
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
      redirect_to organization_path(@organization), alert: 'Teammate associations are only available for companies.'
    end
  end
  
  def authorize_slack_access
    # Allow if user can manage employment OR is an active company teammate
    unless policy(@organization).manage_employment? || current_company_teammate&.organization == @organization
      redirect_to organization_path(@organization), alert: 'You do not have permission to access Slack configuration.'
    end
  end
end

