class Organizations::PublicMaap::AbilitiesController < Organizations::PublicMaap::BaseController
  def index
    # Get all abilities for this organization (company)
    company = @organization.root_company || @organization
    
    @abilities = Ability
      .where(company: company)
      .includes(:company, :department)
      .ordered
    
    # Group by department for display (nil key = company-level abilities)
    @abilities_by_org = @abilities.group_by(&:department)
  end
  
  def show
    @ability = Ability.find_by_param(params[:id])
    
    unless @ability
      raise ActiveRecord::RecordNotFound, "Ability not found"
    end
    
    # Get public and published observations for this ability
    @observations = @ability.observations
      .public_observations
      .published
      .includes(:observer, :observed_teammates, :observation_ratings)
      .recent
  end
end

