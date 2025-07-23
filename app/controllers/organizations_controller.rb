class OrganizationsController < ApplicationController
  before_action :require_authentication
  before_action :set_organization, only: [:show, :edit, :update, :destroy, :switch]
  
  def index
    @organizations = Organization.all.order(:type, :name)
    @current_organization = current_person.current_organization_or_default
  end
  
  def show
    # For now, just redirect to index since we're showing all orgs there
    redirect_to organizations_path
  end
  
  def new
    @organization = Organization.new
  end
  
  def create
    @organization = Organization.new(organization_params)
    
    if @organization.save
      redirect_to organizations_path, notice: 'Organization was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @organization.update(organization_params)
      redirect_to organizations_path, notice: 'Organization was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @organization.destroy
    redirect_to organizations_path, notice: 'Organization was successfully deleted.'
  end
  
  def switch
    if current_person.switch_to_organization(@organization)
      redirect_back(fallback_location: organizations_path, notice: "Switched to #{@organization.display_name}")
    else
      redirect_back(fallback_location: organizations_path, alert: "Failed to switch organization")
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:id])
  end
  
  def organization_params
    params.require(:organization).permit(:name, :type, :parent_id)
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end
end
