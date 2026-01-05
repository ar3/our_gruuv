class Organizations::GetShitDoneController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_teammate
  
  def show
    authorize @teammate, :view_check_ins?
    
    # Load all pending items using centralized service
    query_service = GetShitDoneQueryService.new(teammate: @teammate)
    @observable_moments = query_service.observable_moments
    @maap_snapshots = query_service.maap_snapshots
    @observation_drafts = query_service.observation_drafts
    @goals_needing_check_in = query_service.goals_needing_check_in
    @total_pending = query_service.total_pending_count
  end
  
  private
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access the dashboard.'
    end
  end
  
  def set_teammate
    @teammate = current_company_teammate
  end
end


