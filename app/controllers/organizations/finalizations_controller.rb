class Organizations::FinalizationsController < ApplicationController
  before_action :authenticate_person!
  before_action :set_organization
  before_action :set_person
  before_action :set_teammate
  before_action :authorize_finalization
  
  def show
    # Determine view mode
    if current_person == @person
      @view_mode = :employee
    elsif @person.current_manager_for(@organization) == current_person
      @view_mode = :manager
    else
      @view_mode = :readonly
    end
    
    # Load ALL check-ins for display (ready for finalization + incomplete ones)
    # Ready to finalize
    @ready_position_check_in = PositionCheckIn.where(teammate: @teammate).ready_for_finalization.first
    @ready_assignment_check_ins = AssignmentCheckIn.where(teammate: @teammate).ready_for_finalization
    @ready_aspiration_check_ins = AspirationCheckIn.where(teammate: @teammate).ready_for_finalization
    
    # Partially complete (for display in read-only rows)
    @incomplete_position_check_ins = PositionCheckIn.where(teammate: @teammate)
                                                    .open
                                                    .where.not(employee_completed_at: nil, manager_completed_at: nil)
                                                    .where.not(id: @ready_position_check_in&.id)
    
    @incomplete_assignment_check_ins = AssignmentCheckIn.where(teammate: @teammate)
                                                          .open
                                                          .where.not(id: @ready_assignment_check_ins.map(&:id))
                                                          .where("(employee_completed_at IS NOT NULL AND manager_completed_at IS NULL) OR (employee_completed_at IS NULL AND manager_completed_at IS NOT NULL)")
    
    @incomplete_aspiration_check_ins = AspirationCheckIn.where(teammate: @teammate)
                                                           .open
                                                           .where.not(id: @ready_aspiration_check_ins.map(&:id))
                                                           .where("(employee_completed_at IS NOT NULL AND manager_completed_at IS NULL) OR (employee_completed_at IS NULL AND manager_completed_at IS NOT NULL)")
    
    # Load already finalized check-ins for acknowledgment view
    @finalized_position_check_in = PositionCheckIn.where(teammate: @teammate).closed.order(:official_check_in_completed_at).last
  end
  
  def create
    result = CheckInFinalizationService.new(
      teammate: @teammate,
      finalization_params: finalization_params,
      finalized_by: current_person,
      request_info: build_request_info
    ).call
    
    if result.ok?
      # TODO: Send notification to employee
      redirect_to organization_person_check_ins_path(@organization, @person),
                  notice: 'Check-ins finalized successfully. Employee will be notified.'
    else
      redirect_to organization_person_finalization_path(@organization, @person),
                  alert: "Failed to finalize: #{result.error}"
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def set_person
    @person = Person.find(params[:person_id])
  end
  
  def set_teammate
    # Find teammate within the organization hierarchy
    # This handles cases where a person has a teammate record at a child department
    # but we're viewing finalization at the company level
    @teammate = @person.teammates.for_organization_hierarchy(@organization).first
    
    # If no teammate found, redirect with error
    unless @teammate
      redirect_to organization_person_check_ins_path(@organization, @person),
                  alert: "Unable to find teammate record for #{@person.display_name} in #{@organization.name}"
      return
    end
  end
  
  def authorize_finalization
    # Manager can finalize, employee can acknowledge
    authorize @person, :view_check_ins?, policy_class: PersonPolicy
  end
  
  def finalization_params
    permitted = params.permit(
      position_check_in: [:finalize, :official_rating, :shared_notes],
      assignment_check_ins: {},
      aspiration_check_ins: {}
    )
    
    # Explicitly permit nested parameters for assignment_check_ins
    if permitted[:assignment_check_ins]
      permitted[:assignment_check_ins].each do |check_in_id, assignment_params|
        if assignment_params.is_a?(ActionController::Parameters)
          assignment_params.permit(:finalize, :official_rating, :shared_notes, :anticipated_energy_percentage)
        end
      end
    end
    
    permitted
  end
  
  def build_request_info
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current.iso8601
    }
  end
end
