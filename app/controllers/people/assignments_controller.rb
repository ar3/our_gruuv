class People::AssignmentsController < ApplicationController
  before_action :require_authentication
  before_action :set_person
  before_action :set_assignment
  after_action :verify_authorized

  def show
    # Find the teammate for the assignment's company
    teammate = @person.teammates.find_by(organization: @assignment.company)
    if teammate
      authorize teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    else
      # Fallback: authorize the person directly if no teammate found
      authorize @person, :public?, policy_class: PersonPolicy
    end
    load_assignment_data
    load_tenure_history
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_assignment
    @assignment = Assignment.find(params[:id])
  end

  def load_assignment_data
    teammate = @person.teammates.find_by(organization: @assignment.company)
    @tenure = teammate ? AssignmentTenure.most_recent_for(teammate, @assignment) : nil
    @open_check_in = teammate ? AssignmentCheckIn.find_or_create_open_for(teammate, @assignment) : nil
    @recent_check_ins = teammate ? AssignmentCheckIn
      .where(teammate: teammate, assignment: @assignment)
      .includes(:manager_completed_by_teammate, :finalized_by_teammate)
      .order(check_in_started_on: :desc)
      .limit(5) : []
    
    # Load assignment details
    @assignment_outcomes = @assignment.assignment_outcomes.ordered
    @assignment_abilities = @assignment.assignment_abilities.includes(:ability)
    
    # Get current employment for this assignment's company
    teammate = @person.teammates.find_by(organization: @assignment.company)
    @current_employment = teammate&.employment_tenures&.active&.first
    @position_assignment = nil
    
    # Check if this assignment is connected to the person's current position
    if @current_employment&.position&.position_type
      @position_assignment = PositionAssignment.joins(:position)
        .where(assignment: @assignment)
        .where(positions: { position_type: @current_employment.position.position_type })
        .first
    end
  end

  def load_tenure_history
    teammate = @person.teammates.find_by(organization: @assignment.company)
    @tenure_history = teammate ? AssignmentTenure.where(teammate: teammate, assignment: @assignment).order(started_at: :desc) : []
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access assignment details.'
    end
  end
end
