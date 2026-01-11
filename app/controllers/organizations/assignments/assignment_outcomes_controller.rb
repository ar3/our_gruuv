class Organizations::Assignments::AssignmentOutcomesController < Organizations::AssignmentsController
  before_action :set_assignment
  before_action :set_assignment_outcome
  after_action :verify_authorized

  def edit
    authorize @assignment_outcome
    
    # Set return URL and text for overlay
    return_params = params.except(:controller, :action, :id, :assignment_id).permit!.to_h
    @return_url = organization_assignments_path(@organization, return_params)
    @return_text = "Back to Assignments"
    
    render layout: 'overlay'
  end

  def update
    authorize @assignment_outcome
    
    if @assignment_outcome.update(assignment_outcome_params)
      # Build return URL with preserved params (excluding organization_id which is in the path)
      return_params = params.except(:controller, :action, :id, :assignment_id, :organization_id, :assignment_outcome, :utf8, :_method, :commit).permit!.to_h
      redirect_to organization_assignments_path(@organization, return_params), notice: 'Outcome was successfully updated.'
    else
      # Set return URL and text for overlay
      return_params = params.except(:controller, :action, :id, :assignment_id, :organization_id, :assignment_outcome, :utf8, :_method, :commit).permit!.to_h
      @return_url = organization_assignments_path(@organization, return_params)
      @return_text = "Back to Assignments"
      render :edit, status: :unprocessable_entity, layout: 'overlay'
    end
  end

  private

  def set_assignment
    @assignment = @organization.assignments.find(params[:assignment_id])
  end

  def set_assignment_outcome
    @assignment_outcome = @assignment.assignment_outcomes.find(params[:id])
  end

  def assignment_outcome_params
    params.require(:assignment_outcome).permit(:description, :outcome_type)
  end
end
