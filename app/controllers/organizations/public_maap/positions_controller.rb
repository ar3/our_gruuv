class Organizations::PublicMaap::PositionsController < Organizations::PublicMaap::BaseController
  def index
    # Get all positions for this organization (company)
    company = @organization.root_company || @organization
    
    @positions = Position
      .joins(:title)
      .where(titles: { company_id: company.id })
      .includes(title: [:company, :department], position_level: :position_major_level)
      .ordered
    
    # Group by department for display (nil key = company-level positions)
    @positions_by_org = @positions.group_by { |pos| pos.title.department }
  end
  
  def show
    @position = Position.find_by_param(params[:id])
    
    unless @position
      raise ActiveRecord::RecordNotFound, "Position not found"
    end
  end
end

