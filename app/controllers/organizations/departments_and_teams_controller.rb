class Organizations::DepartmentsAndTeamsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication

  def index
    # Get all descendants (departments and teams) with their hierarchy
    @departments_and_teams = @organization.descendants
    
    # Group by parent for hierarchy display
    @hierarchy = build_hierarchy(@organization)
  end

  private

  def build_hierarchy(org, level = 0)
    children = org.children.includes(:children).order(:type, :name)
    result = []
    
    children.each do |child|
      result << {
        organization: child,
        level: level,
        children: build_hierarchy(child, level + 1)
      }
    end
    
    result
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access departments and teams.'
    end
  end
end
