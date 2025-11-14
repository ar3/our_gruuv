class Organizations::Teammates::AssignmentsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_assignment
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy
    
    # Load all check-ins (full history)
    @check_ins = AssignmentCheckIn
      .where(teammate: @teammate, assignment: @assignment)
      .includes(:manager_completed_by, :finalized_by)
      .order(check_in_started_on: :desc)
    
    # Load assignment details
    @assignment_outcomes = @assignment.assignment_outcomes.ordered
    @assignment_abilities = @assignment.assignment_abilities.includes(:ability)
    
    # Load tenure history
    @tenure_history = AssignmentTenure
      .where(teammate: @teammate, assignment: @assignment)
      .order(started_at: :desc)
    
    # Load current/open check-in
    @open_check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, @assignment)
    
    # Get current employment for position connection
    @current_employment = @teammate.employment_tenures.active.first
    @position_assignment = nil
    
    # Check if this assignment is connected to the teammate's current position
    if @current_employment&.position&.position_type
      @position_assignment = PositionAssignment.joins(:position)
        .where(assignment: @assignment)
        .where(positions: { position_type: @current_employment.position.position_type })
        .first
    end
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def set_assignment
    @assignment = Assignment.find(params[:id])
  end
end

