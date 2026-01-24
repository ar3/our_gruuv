class Organizations::PublicMaap::PositionsController < Organizations::PublicMaap::BaseController
  def index
    # Get all positions for this organization and its departments (exclude teams)
    company = @organization.root_company || @organization
    orgs_in_hierarchy = [company] + company.descendants.select { |org| org.department? }
    
    @positions = Position
      .joins(title: :organization)
      .where(organizations: { id: orgs_in_hierarchy })
      .includes(title: :organization, position_level: :position_major_level)
      .ordered
    
    # Group by organization for display
    @positions_by_org = @positions.group_by { |pos| pos.title.organization }
  end
  
  def show
    @position = Position.find_by_param(params[:id])
    
    unless @position
      raise ActiveRecord::RecordNotFound, "Position not found"
    end
  end
end

