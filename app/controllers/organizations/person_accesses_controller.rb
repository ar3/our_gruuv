class Organizations::PersonAccessesController < ApplicationController
  before_action :require_login
  before_action :set_organization
  before_action :set_person_organization_access, only: [:edit, :update, :destroy]
  after_action :verify_authorized

  def new
    @person_organization_access = PersonOrganizationAccess.new
    @person_organization_access.organization = @organization
    @person_organization_access.person = current_person
    authorize @person_organization_access
  end

  def create
    @person_organization_access = PersonOrganizationAccess.new(person_organization_access_params)
    @person_organization_access.organization = @organization
    @person_organization_access.person = current_person
    authorize @person_organization_access

    if @person_organization_access.save
      redirect_to profile_path, notice: 'Organization permission was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @person_organization_access
  end

  def update
    authorize @person_organization_access
    
    if @person_organization_access.update(person_organization_access_params)
      redirect_to profile_path, notice: 'Organization permission was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @person_organization_access
    @person_organization_access.destroy
    redirect_to profile_path, notice: 'Organization permission was successfully removed.'
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page'
    end
  end

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_person_organization_access
    @person_organization_access = @organization.person_organization_accesses.find(params[:id])
  end

  def person_organization_access_params
    params.require(:person_organization_access).permit(:can_manage_employment, :can_manage_maap)
  end
end
