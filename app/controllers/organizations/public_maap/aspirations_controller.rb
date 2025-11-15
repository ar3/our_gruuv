class Organizations::PublicMaap::AspirationsController < Organizations::PublicMaap::BaseController
  def index
    # Get all aspirations for this organization and its departments (exclude teams)
    # Note: Aspirations don't have a public/private flag, so we show all
    company = @organization.root_company || @organization
    orgs_in_hierarchy = [company] + company.descendants.select { |org| org.department? }
    
    @aspirations = Aspiration
      .where(organization: orgs_in_hierarchy)
      .includes(:organization)
      .ordered
    
    # Group by organization for display
    @aspirations_by_org = @aspirations.group_by(&:organization)
  end
  
  def show
    @aspiration = Aspiration.find_by_param(params[:id])
    
    unless @aspiration
      raise ActiveRecord::RecordNotFound, "Aspiration not found"
    end
    
    # Get public and published observations for this aspiration
    @observations = @aspiration.observations
      .public_observations
      .published
      .includes(:observer, :observed_teammates, :observation_ratings)
      .recent
  end
end

