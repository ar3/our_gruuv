class Organizations::PublicMaap::AspirationsController < Organizations::PublicMaap::BaseController
  def index
    # Get all aspirations for this organization (company)
    # Note: Aspirations don't have a public/private flag, so we show all
    company = @organization.root_company || @organization
    
    @aspirations = Aspiration
      .where(company: company)
      .includes(:company, :department)
      .ordered
    
    # Group by department for display (nil key = company-level aspirations)
    @aspirations_by_org = @aspirations.group_by(&:department)
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


