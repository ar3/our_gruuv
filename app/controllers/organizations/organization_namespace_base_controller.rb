class Organizations::OrganizationNamespaceBaseController < ApplicationController
  before_action :ensure_teammate_matches_organization, unless: :skip_organization_setup?
  before_action :set_organization, unless: :skip_organization_setup?
  helper_method :organization

  # Override Pundit's default user method to use current_company_teammate
  def pundit_user
    OpenStruct.new(
      user: current_company_teammate,
      impersonating_teammate: impersonating_teammate
    )
  end

  protected

  def ensure_teammate_matches_organization
    return unless current_company_teammate
    
    route_org = Organization.find(params[:organization_id] || params[:id])
    
    # Since only CompanyTeammates log in and companies are top-level,
    # check for exact company match
    return if current_company_teammate.organization == route_org
    
    # Find CompanyTeammate for the route company
    # Since only CompanyTeammates log in, filter for CompanyTeammate type
    company_teammate = current_company_teammate.person.active_teammates
                                                 .where(type: 'CompanyTeammate')
                                                 .where(organization_id: route_org.id)
                                                 .first
    
    if company_teammate
      # Switch to the teammate for this company
      session[:current_company_teammate_id] = company_teammate.id
      # Clear cached teammate so it reloads
      @current_company_teammate = nil
    else
      # User doesn't have access to this company
      flash[:alert] = "You don't have access to that organization."
      redirect_to organizations_path
    end
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
