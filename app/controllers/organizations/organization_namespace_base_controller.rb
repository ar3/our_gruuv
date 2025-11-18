class Organizations::OrganizationNamespaceBaseController < ApplicationController
  before_action :ensure_teammate_matches_organization, unless: :skip_organization_setup?
  before_action :set_organization, unless: :skip_organization_setup?
  helper_method :organization

  # Override Pundit's default user method to use current_company_teammate
  def pundit_user
    OpenStruct.new(
      user: current_company_teammate,
      impersonating_teammate: impersonator_teammate
    )
  end

  protected

  def ensure_teammate_matches_organization
    return unless current_company_teammate
    
    route_org = Organization.find(params[:organization_id] || params[:id])
    route_root_company = route_org.root_company || route_org
    
    current_root_company = current_company_teammate.organization.root_company || current_company_teammate.organization
    
    # If teammate's organization matches route's root company, no action needed
    return if current_root_company == route_root_company
    
    # Find active teammate for route's root company
    active_teammate = current_company_teammate.person.active_teammates
                                                 .joins(:organization)
                                                 .where(organizations: { id: route_root_company.self_and_descendants })
                                                 .first
    
    if active_teammate
      # Ensure it's a CompanyTeammate for root company
      company_teammate = ensure_company_teammate(active_teammate) || active_teammate
      # Switch to the teammate for this organization
      session[:current_company_teammate_id] = company_teammate.id
      # Clear cached teammate so it reloads
      @current_company_teammate = nil
    elsif allow_authorization_for_different_org?
      # For people views, allow authorization check to determine access
      # The organization context is still set via set_organization
      return
    else
      # User doesn't have access to this organization
      flash[:alert] = "You don't have access to that organization."
      redirect_to organizations_path
    end
  end

  # Override this method in child controllers to allow authorization checks
  # even when user doesn't have access to the organization
  # (e.g., for people views that should redirect to public view on failure)
  def allow_authorization_for_different_org?
    false
  end

  def set_organization
    @organization = organization
  end

  def organization
    @organization ||= Organization.find(params[:organization_id] || params[:id])
  end

  # Override this method in child controllers to skip organization setup for certain actions
  def skip_organization_setup?
    false
  end
end
