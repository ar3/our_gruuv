class Organizations::AspirationsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_aspiration, only: [:show, :edit, :update, :destroy]

  def index
    # Show aspirations for the entire company hierarchy
    company = @organization.root_company
    @aspirations = policy_scope(Aspiration).where(organization: company.self_and_descendants).ordered
    authorize @aspirations
    render layout: 'authenticated-v2-0'
  end

  def show
    authorize @aspiration
    render layout: 'authenticated-v2-0'
  end

  def new
    @aspiration = @organization.aspirations.build
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    authorize @aspiration
    render layout: 'authenticated-v2-0'
  end

  def create
    # Get the selected organization from params
    selected_org_id = aspiration_params[:organization_id] || @organization.id
    selected_org = Organization.find(selected_org_id)
    
    @aspiration = selected_org.aspirations.build
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    authorize @aspiration

    if @form.validate(aspiration_params) && @form.save
      redirect_to organization_aspirations_path(@organization), notice: 'Aspiration was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    authorize @aspiration
    render layout: 'authenticated-v2-0'
  end

  def update
    @form = AspirationForm.new(@aspiration)
    @form.current_person = current_person
    authorize @aspiration

    # Get the selected organization from params
    selected_org_id = aspiration_params[:organization_id] || @aspiration.organization_id
    selected_org = Organization.find(selected_org_id)
    
    # Update the aspiration with new organization if changed
    if selected_org_id != @aspiration.organization_id
      @aspiration.organization = selected_org
    end

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
    @aspiration = @organization.aspirations.find(params[:id])
  end

  def aspiration_params
    params.require(:aspiration).permit(:name, :description, :sort_order, :organization_id)
  end
end
