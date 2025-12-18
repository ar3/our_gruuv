class Organizations::PublicMaap::AssignmentsController < Organizations::PublicMaap::BaseController
  def index
    # Get all assignments for this organization and its departments (exclude teams)
    company = @organization.root_company || @organization
    orgs_in_hierarchy = [company] + company.descendants.select { |org| org.department? }
    
    @assignments = Assignment
      .where(company: orgs_in_hierarchy)
      .includes(:company, :department)
      .ordered
    
    # Group by department for display
    @assignments_by_department = @assignments.group_by(&:department)
  end
  
  def show
    @assignment = Assignment.find_by_param(params[:id])
    
    unless @assignment
      raise ActiveRecord::RecordNotFound, "Assignment not found"
    end
    
    # Get public and published observations for this assignment
    @observations = @assignment.observations
      .public_observations
      .published
      .includes(:observer, :observed_teammates, :observation_ratings)
      .recent
  end
end

