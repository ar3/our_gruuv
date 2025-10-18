class Organizations::FinalizationsController < ApplicationController
  before_action :authenticate_person!
  before_action :set_organization
  before_action :set_person
  before_action :set_teammate
  before_action :authorize_finalization
  
  def show
    # Load all ready-to-finalize check-ins (for managers)
    @position_check_in = PositionCheckIn.where(teammate: @teammate).ready_for_finalization.first
    @assignment_check_ins = AssignmentCheckIn.where(teammate: @teammate).ready_for_finalization
    
    # If no ready check-ins, load the most recent finalized ones (for employees to acknowledge)
    if @position_check_in.nil?
      @position_check_in = PositionCheckIn.where(teammate: @teammate).closed.order(:official_check_in_completed_at).last
    end
    
    # Load aspiration check-ins ready for finalization
    @aspiration_check_ins = AspirationCheckIn.where(teammate: @teammate).ready_for_finalization
    
    # If no ready aspiration check-ins, load the most recent finalized ones (for employees to acknowledge)
    if @aspiration_check_ins.empty?
      @aspiration_check_ins = AspirationCheckIn.where(teammate: @teammate).closed.order(:official_check_in_completed_at).last(5)
    end
  end
  
  def create
    result = CheckInFinalizationService.new(
      teammate: @teammate,
      finalization_params: finalization_params,
      finalized_by: current_person
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
    @teammate = @person.teammates.find_by(organization: @organization)
  end
  
  def authorize_finalization
    # Manager can finalize, employee can acknowledge
    authorize @person, :view_check_ins?
  end
  
  def finalization_params
    params.permit(
      :finalize_position,
      :finalize_assignments,
      :finalize_aspirations,
      :position_official_rating,
      :position_shared_notes,
      assignment_check_ins: [:assignment_id, :official_rating, :shared_notes],
      aspiration_check_ins: [:aspiration_id, :official_rating, :shared_notes]
      # Add more params in later phases
    )
  end
  
  def build_request_info
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current.iso8601
    }
  end
end
