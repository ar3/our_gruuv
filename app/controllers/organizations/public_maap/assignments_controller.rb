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
    # If assignment has no department but company is a department, use company
    @assignments_by_department = @assignments.group_by do |assignment|
      assignment.department || (assignment.company.department? ? assignment.company : nil)
    end
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

