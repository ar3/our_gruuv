class Organizations::ObservableMomentsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_observable_moment, except: [:ignore_all]
  before_action :authorize_observer, except: [:ignore_all]

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

      redirect_to organization_get_shit_done_path(organization, open: 'observableMomentsSection'),
                  notice: 'Observable moment reassigned successfully.'
    end
  end

  def ignore
    @observable_moment.update!(
      processed_at: Time.current,
      processed_by_teammate: current_company_teammate
    )

    redirect_to organization_get_shit_done_path(organization, open: 'observableMomentsSection'),
                notice: 'Observable moment ignored.'
  end

  def ignore_all
    moments = GetShitDoneQueryService.new(teammate: current_company_teammate).observable_moments
    count = 0
    moments.find_each do |moment|
      moment.update!(
        processed_at: Time.current,
        processed_by_teammate: current_company_teammate
      )
      count += 1
    end

    notice =
      if count.zero?
        'No observable moments to ignore.'
      else
        "Ignored #{count} #{'observable moment'.pluralize(count)}."
      end

    redirect_to organization_get_shit_done_path(organization, open: 'observableMomentsSection'),
                notice: notice
  end

  private

  def require_authentication
    unless current_person
      redirect_unauthenticated_to_login!(message: 'Please log in to access observable moments.', flash_key: :alert)
    end
  end

  def set_observable_moment
    @observable_moment = ObservableMoment.find(params[:id])
  end

  def authorize_observer
    unless @observable_moment.primary_potential_observer == current_company_teammate
      redirect_to organization_get_shit_done_path(organization, open: 'observableMomentsSection'),
                  alert: 'You are not authorized to perform this action.'
    end
  end
end
