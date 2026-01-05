class Organizations::ObservableMomentsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_observable_moment
  before_action :authorize_observer
  
  def create_observation
    redirect_to new_organization_observation_path(
      organization,
      observable_moment_id: @observable_moment.id
    )
  end
  
  def reassign
    if request.get?
      @teammates = organization.teammates.where(last_terminated_at: nil).order('people.first_name, people.last_name').includes(:person)
      render :reassign
    else
      new_teammate = CompanyTeammate.find_by(id: params[:teammate_id], organization: organization)
      
      unless new_teammate
        redirect_to reassign_organization_observable_moment_path(organization, @observable_moment),
                    alert: 'Invalid teammate selected.'
        return
      end
      
      @observable_moment.reassign_to(new_teammate)
      
      redirect_to organization_get_shit_done_path(organization),
                  notice: 'Observable moment reassigned successfully.'
    end
  end
  
  def ignore
    @observable_moment.update!(
      processed_at: Time.current,
      processed_by_teammate: current_company_teammate
    )
    
    redirect_to organization_get_shit_done_path(organization),
                notice: 'Observable moment ignored.'
  end
  
  private
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access observable moments.'
    end
  end
  
  def set_observable_moment
    @observable_moment = ObservableMoment.find(params[:id])
  end
  
  def authorize_observer
    unless @observable_moment.primary_potential_observer == current_company_teammate
      redirect_to organization_get_shit_done_path(organization),
                  alert: 'You are not authorized to perform this action.'
    end
  end
end

