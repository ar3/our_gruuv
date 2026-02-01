class Organizations::AspirationsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_aspiration, only: [:show, :edit, :update, :destroy]

  def index
    authorize company, :view_aspirations?
    # Show aspirations for the company
    @aspirations = policy_scope(Aspiration).for_company(company).ordered
    render layout: determine_layout
  end

  def show
    authorize @aspiration
    
    # Load public observations (public_to_company or public_to_world) for this aspiration
    @observations = @aspiration.observations
      .where(privacy_level: ['public_to_company', 'public_to_world'])
      .published
      .includes(:observer, { observed_teammates: :person }, :observation_ratings)
      .recent
    
    render layout: determine_layout
  end

  def new
    @aspiration = Aspiration.new(company: company)
    @aspiration_decorator = AspirationDecorator.new(@aspiration)
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    @form.instance_variable_set(:@form_data_empty, true)
    @departments = Department.for_company(company).active.ordered
    authorize @aspiration
    render layout: determine_layout
  end

  def create
    @aspiration = Aspiration.new(company: company)
    @aspiration_decorator = AspirationDecorator.new(@aspiration)
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered
    
    # Set flag for empty form data validation
    aspiration_params_hash = aspiration_params || {}
    @form.instance_variable_set(:@form_data_empty, aspiration_params_hash.empty?)
    
    authorize @aspiration

    if @form.validate(aspiration_params) && @form.save
      redirect_to organization_aspirations_path(@organization), notice: 'Aspiration was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @aspiration_decorator = AspirationDecorator.new(@aspiration)
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered
    authorize @aspiration
    render layout: determine_layout
  end

  def update
    @aspiration_decorator = AspirationDecorator.new(@aspiration)
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered
    authorize @aspiration

    # Set flag for empty form data validation
    aspiration_params_hash = aspiration_params || {}
    @form.instance_variable_set(:@form_data_empty, aspiration_params_hash.empty?)

    if @form.validate(aspiration_params) && @form.save
      redirect_to organization_aspirations_path(@organization), notice: 'Aspiration was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @aspiration
    @aspiration.soft_delete!
    redirect_to organization_aspirations_path(@organization), notice: 'Aspiration was successfully deleted.'
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_aspiration
    @aspiration = company.aspirations.find(params[:id])
  end

  def aspiration_params
    params.require(:aspiration).permit(:name, :description, :sort_order, :department_id, :version_type)
  end
end
