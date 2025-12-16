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
    user_company = current_company_teammate.organization
    
    # Since only CompanyTeammates log in and companies are top-level,
    # check for exact company match
    return if user_company == route_org
    
    # Allow access if route_org is a descendant of user's company
    # This allows accessing departments/teams within the user's company
    if user_company.self_and_descendants.include?(route_org)
      return
    end
    
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
      # For observation show actions, redirect to kudos page instead of organizations
      if controller_name == 'observations' && action_name == 'show' && params[:id].present?
        observation = Observation.find_by(id: params[:id])
        if observation.present?
          date_part = observation.observed_at.strftime('%Y-%m-%d')
          redirect_to organization_kudo_path(route_org, date: date_part, id: observation.id)
          return
        end
      end
      
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

  def company
    @company ||= organization.root_company || organization
  end
  helper_method :company

  # Override this method in child controllers to skip organization setup for certain actions
  def skip_organization_setup?
    false
  end
end
