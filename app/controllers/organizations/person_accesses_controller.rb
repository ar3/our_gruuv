class Organizations::PersonAccessesController < Organizations::OrganizationNamespaceBaseController
  before_action :require_login
  before_action :set_teammate, only: [:edit, :update, :destroy]
  after_action :verify_authorized

  def new
    @teammate = Teammate.new
    @teammate.organization = @organization
    @teammate.person = current_person
    authorize @teammate
  end

  def create
    @teammate = Teammate.new(teammate_params)
    @teammate.organization = @organization
    @teammate.person = current_person
    authorize @teammate

    if @teammate.save
      redirect_to organization_person_path(@organization, current_person), notice: 'Organization permission was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @teammate
  end

  def update
    authorize @teammate
    
    if @teammate.update(teammate_params)
      redirect_to organization_person_path(@organization, current_person), notice: 'Organization permission was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @teammate
    @teammate.destroy
    redirect_to organization_person_path(@organization, current_person), notice: 'Organization permission was successfully removed.'
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page'
    end
  end

  def set_teammate
    @teammate = @organization.teammates.find(params[:id])
  end

  def teammate_params
    params.require(:teammate).permit(:can_manage_employment, :can_manage_maap, :can_manage_prompts)
  end
end
