class Organizations::CompanyTeammates::FinalizationsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :authorize_finalization
  
  def show
    @person = @teammate.person
    # Determine view mode
    current_manager = @teammate.current_manager
    if current_person == @teammate.person
      @view_mode = :employee
    elsif current_manager == current_person
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
      finalized_by: current_company_teammate,
      request_info: build_request_info,
      maap_snapshot_reason: finalization_params[:maap_snapshot_reason]
    ).call
    
    if result.ok?
      # TODO: Send notification to employee
      redirect_to audit_organization_employee_path(organization, @teammate),
                  notice: 'Check-ins finalized successfully. Employee will be notified.'
    else
      redirect_to organization_company_teammate_finalization_path(organization, @teammate),
                  alert: "Failed to finalize: #{result.error}"
    end
  end
  
  private
  
  def set_teammate
    @teammate = organization.teammates.find(params[:company_teammate_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to organization_path(organization),
                alert: "Unable to find teammate record in #{organization.name}"
  end
  
  def authorize_finalization
    # Manager can finalize, employee can acknowledge
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
  end
  
  def finalization_params
    permitted = params.permit(
      :maap_snapshot_reason,
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

