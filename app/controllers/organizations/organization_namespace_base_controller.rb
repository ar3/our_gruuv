class Organizations::OrganizationNamespaceBaseController < ApplicationController
  before_action :ensure_teammate_matches_organization, unless: :skip_organization_setup?
  before_action :set_organization, unless: :skip_organization_setup?
  helper_method :organization
  helper_method :company

  # Override Pundit's default user method to use current_company_teammate
  def pundit_user
    OpenStruct.new(
      user: current_company_teammate,
      impersonating_teammate: impersonating_teammate
    )
  end

  protected

  def organization_param
    # Only use params[:id] if we're in the OrganizationsController itself
    # In nested routes, params[:id] refers to the nested resource (e.g., seat, goal)
    if controller_name == 'organizations'
      params[:id]
    else
      params[:organization_id]
    end
  end

  def ensure_teammate_matches_organization
    raise "Organization Not Found: #{organization_param}" if organization.nil?
    
    if current_company_teammate.nil?
      flash[:alert] = "Your session has expired. Please log in again."
      redirect_to root_path
      return
    end
    
    return if organization.id == current_company_teammate.organization.id
      
    # User doesn't have access to this company
    flash[:alert] = "You don't have access to that organization."
    redirect_to dashboard_organization_path(current_company_teammate.organization)
  end

  def set_organization
    @organization = organization
  end

  def organization
    org_param = organization_param
    return nil unless org_param.present?
    
    @organization ||= Organization.find_by_param(org_param)
  end

  def company
    @company ||= organization.root_company || organization
  end
  helper_method :company

  # Override this method in child controllers to skip organization setup for certain actions
  def skip_organization_setup?
    false
  end
end
