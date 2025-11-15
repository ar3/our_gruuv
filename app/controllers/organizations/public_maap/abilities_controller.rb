class Organizations::PublicMaap::AbilitiesController < Organizations::PublicMaap::BaseController
  def index
    # Get all abilities for this organization and its departments (exclude teams)
    company = @organization.root_company || @organization
    orgs_in_hierarchy = [company] + company.descendants.select { |org| org.department? }
    
    @abilities = Ability
      .where(organization: orgs_in_hierarchy)
      .includes(:organization)
      .ordered
    
    # Group by organization for display
    @abilities_by_org = @abilities.group_by(&:organization)
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

