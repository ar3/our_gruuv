class Organizations::KudosController < ApplicationController
  layout 'public_maap'
  
  before_action :set_organization
  before_action :set_observation, only: [:show]
  before_action :authorize_view_permalink, only: [:show]

  # Override Pundit's default user method to return Teammate structure
  # Policies expect a Teammate, not a Person
  def pundit_user
    OpenStruct.new(
      user: current_company_teammate,
      impersonating_teammate: impersonating_teammate
    )
  end

  # Override the rescue behavior to redirect with flash message
  def user_not_authorized(exception)
    flash[:alert] = "You are not authorized to view this observation"
    redirect_to root_path
  end

  def index
    # Get all public observations for organization and its descendants
    company = @organization.root_company || @organization
    orgs_in_hierarchy = [company] + company.descendants.to_a
    
    @observations = Observation
      .where(company: orgs_in_hierarchy)
      .public_observations
      .published
      .includes(:observer, :observed_teammates, :observation_ratings)
      .recent
  end

  def show
    # This is the public permalink page that respects privacy settings
    # No authentication required for public observations
  end

  private

  def set_organization
    org_param = params[:organization_id]
    @organization = Organization.find_by_param(org_param)
    
    unless @organization
      raise ActiveRecord::RecordNotFound, "Organization not found"
    end
  end

  def set_observation
    date = params[:date]
    id = params[:id]
    
    # Parse the permalink_id format: "2025-10-05-142" or "2025-10-05-142-custom-slug"
    permalink_id = "#{date}-#{id}"
    @observation = Observation.find_by_permalink_id(permalink_id)
    
    unless @observation
      raise ActiveRecord::RecordNotFound, "Observation not found"
    end
    
    # Set organization from observation's company
    @organization = @observation.company
  end

  def authorize_view_permalink
    # For public observations, no authentication required
    return if @observation.privacy_level == 'public_observation'
    
    # For other privacy levels, require authentication
    unless current_person
      authenticate_person!
      return
    end
    
    # Check authorization and raise error before Pundit's rescue_from catches it
    # This allows tests to catch the error directly
    unless policy(@observation).view_permalink?
      raise Pundit::NotAuthorizedError.new(
        query: :view_permalink?,
        record: @observation,
        policy: policy(@observation)
      )
    end
  end
end

