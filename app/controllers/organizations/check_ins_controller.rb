class Organizations::CheckInsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_person
  after_action :verify_authorized

  def show
    authorize @person, :manager?, policy_class: PersonPolicy
    load_check_in_data
  end

  def finalize_check_in
    authorize @person, :manager?, policy_class: PersonPolicy
    
    check_in = AssignmentCheckIn.find(params[:check_in_id])
    
    if check_in.ready_for_finalization?
      if params[:final_rating].present?
        check_in.update!(shared_notes: params[:shared_notes])
        
        # Handle close_rating checkbox
        if params[:close_rating] == 'true'
          check_in.finalize_check_in!(final_rating: params[:final_rating], finalized_by: current_person)
          redirect_to organization_check_in_path(@organization, @person), notice: 'Check-in finalized and closed successfully.'
        else
          check_in.update!(official_rating: params[:final_rating])
          redirect_to organization_check_in_path(@organization, @person), notice: 'Final rating saved. Check-in remains open for further updates.'
        end
      else
        redirect_to organization_check_in_path(@organization, @person), alert: 'Final rating is required to finalize the check-in.'
      end
    else
      redirect_to organization_check_in_path(@organization, @person), alert: 'Check-in is not ready for finalization. Both employee and manager must complete their sections first.'
    end
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def load_check_in_data
    # Get check-ins that have at least one side completed (employee or manager)
    # Filter by assignments within the current organization
    @check_ins_in_progress = AssignmentCheckIn
      .joins(:assignment)
      .where(person: @person)
      .where(assignments: { company: @organization })
      .where.not(employee_completed_at: nil)
      .or(AssignmentCheckIn
        .joins(:assignment)
        .where(person: @person)
        .where(assignments: { company: @organization })
        .where.not(manager_completed_at: nil))
      .where(official_check_in_completed_at: nil) # Not yet finalized
      .includes(:assignment)
      .order(:check_in_started_on)
    
    # Determine what information the current user can see
    @is_employee = current_person == @person
    @is_manager = !@is_employee && policy(@person).manager?
    @can_see_both_sides = @check_ins_in_progress.any? { |ci| ci.ready_for_finalization? }
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access check-ins.'
    end
  end
end
