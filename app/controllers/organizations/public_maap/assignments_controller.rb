class Organizations::PublicMaap::AssignmentsController < Organizations::PublicMaap::BaseController
  def index
    # Get all assignments for this organization (company)
    company = @organization.root_company || @organization
    
    @assignments = Assignment
      .where(company: company)
      .includes(:company, :department)
      .ordered
    
    # Group by department for display (nil key = company-level assignments)
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

