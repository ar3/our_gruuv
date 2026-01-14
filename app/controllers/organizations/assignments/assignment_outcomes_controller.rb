class Organizations::Assignments::AssignmentOutcomesController < Organizations::AssignmentsController
  before_action :set_assignment
  before_action :set_assignment_outcome
  after_action :verify_authorized

  def edit
    authorize @assignment_outcome
    
    # Set return URL and text for overlay
    @return_url = organization_assignment_path(@organization, @assignment)
    @return_text = "Back to Assignment"
    
    render layout: 'overlay'
  end

  def update
    authorize @assignment_outcome
    
    if @assignment_outcome.update(assignment_outcome_params)
      redirect_to organization_assignment_path(@organization, @assignment), notice: 'Outcome was successfully updated.'
    else
      # Set return URL and text for overlay
      @return_url = organization_assignment_path(@organization, @assignment)
      @return_text = "Back to Assignment"
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
    permitted = params.require(:assignment_outcome).permit(
      :description, 
      :outcome_type,
      :progress_report_url,
      :management_relationship_filter,
      :team_relationship_filter,
      :consumer_assignment_filter
    )
    
    # Normalize empty strings to nil for optional filter fields
    permitted[:management_relationship_filter] = nil if permitted[:management_relationship_filter].blank?
    permitted[:team_relationship_filter] = nil if permitted[:team_relationship_filter].blank?
    permitted[:consumer_assignment_filter] = nil if permitted[:consumer_assignment_filter].blank?
    
    permitted
  end
end
