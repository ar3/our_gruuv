class Organizations::ObservationsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_observation, only: [:show, :edit, :update, :destroy]

  def index
    authorize Observation
    # Use ObservationVisibilityQuery for complex visibility logic
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    @observations = visibility_query.visible_observations.includes(:observer, :observed_teammates, :observation_ratings)
    @observations = @observations.recent
  end

  def show
    # Show page is only for the observer
    begin
      authorize @observation, :show?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end
  end

  def new
    authorize Observation
    @observation = Observation.new(company: organization, observer: current_person)
    @observation.observees.build
  end

  def create
    authorize Observation
    @observation = Observation.new(observation_params)
    @observation.company = organization
    @observation.observer = current_person

    if @observation.save
      redirect_to organization_observation_path(organization, @observation), 
                  notice: 'Observation was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit is only for the observer
    begin
      authorize @observation, :edit?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end
  end

  def update
    # Update is only for the observer
    begin
      authorize @observation, :update?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end

    if @observation.update(observation_params)
      redirect_to organization_observation_path(organization, @observation), 
                  notice: 'Observation was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Destroy is only for the observer (within 24 hours) or admin
    begin
      authorize @observation, :destroy?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end

    @observation.soft_delete!
    redirect_to organization_observations_path(organization), 
                notice: 'Observation was successfully deleted.'
  end

  def journal
    authorize Observation
    # Use ObservationVisibilityQuery for complex visibility logic
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    @observations = visibility_query.visible_observations.journal.includes(:observer, :observed_teammates, :observation_ratings)
    @observations = @observations.recent
    render :index
  end

  private

  def set_observation
    @observation = Observation.find(params[:id])
  end

  def observation_params
    params.require(:observation).permit(
      :story, :privacy_level, :primary_feeling, :secondary_feeling, 
      :observed_at, :custom_slug,
      observees_attributes: [:id, :teammate_id, :_destroy],
      observation_ratings_attributes: [:id, :rateable_type, :rateable_id, :rating, :_destroy]
    )
  end
end
