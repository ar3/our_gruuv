class Organizations::PublicMaap::AssignmentsController < Organizations::PublicMaap::BaseController
  def index
    @assignments = Assignment
      .unarchived
      .where(company: @organization)
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
    
    # Get public and published observations for this assignment (observed_teammates: :person avoids N+1 on person in view)
    @observations = @assignment.observations
      .public_observations
      .published
      .includes(:observer, :observation_ratings, observed_teammates: :person)
      .recent
  end
end

