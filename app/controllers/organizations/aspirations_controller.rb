class Organizations::AspirationsController < ApplicationController
  before_action :set_organization
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
    authorize @aspiration
    render layout: 'authenticated-v2-0'
  end

  def create
    # Get the selected organization from params
    selected_org_id = aspiration_params[:organization_id] || @organization.id
    selected_org = Organization.find(selected_org_id)
    
    @aspiration = selected_org.aspirations.build(aspiration_params.except(:organization_id))
    authorize @aspiration

    if @aspiration.save
      redirect_to organization_aspirations_path(@organization), notice: 'Aspiration was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @aspiration
    render layout: 'authenticated-v2-0'
  end

  def update
    authorize @aspiration

    # Get the selected organization from params
    selected_org_id = aspiration_params[:organization_id] || @aspiration.organization_id
    selected_org = Organization.find(selected_org_id)
    
    # Update the aspiration with new organization if changed
    update_params = aspiration_params.except(:organization_id)
    if selected_org_id != @aspiration.organization_id
      @aspiration.organization = selected_org
    end

    if @aspiration.update(update_params)
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
