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
          real_user = session[:impersonating_person_id] ? Person.find(session[:impersonating_person_id]) : current_person
          check_in.finalize_check_in!(final_rating: params[:final_rating], finalized_by: real_user)
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

  def bulk_finalize_check_ins
    Rails.logger.info "BULK_FINALIZE: 1 - Starting bulk_finalize_check_ins for person #{@person.id} (#{@person.full_name})"
    Rails.logger.info "BULK_FINALIZE: 2 - Current user: #{current_person.id} (#{current_person.full_name})"
    Rails.logger.info "BULK_FINALIZE: 3 - Organization: #{@organization.id} (#{@organization.name})"
    Rails.logger.info "BULK_FINALIZE: 4 - Impersonation session: #{session[:impersonating_person_id]}"
    
    authorize @person, :manager?, policy_class: PersonPolicy
    Rails.logger.info "BULK_FINALIZE: 5 - Authorization passed"
    
    # Get all check-ins ready for finalization
    ready_check_ins = AssignmentCheckIn
      .joins(:assignment)
      .where(person: @person)
      .where(assignments: { company: @organization })
      .where.not(employee_completed_at: nil)
      .where.not(manager_completed_at: nil)
      .where(official_check_in_completed_at: nil)
    
    Rails.logger.info "BULK_FINALIZE: 6 - Ready check-ins query executed, count: #{ready_check_ins.count}"
    
    if ready_check_ins.any?
      Rails.logger.info "BULK_FINALIZE: 7 - Processing #{ready_check_ins.count} ready check-ins"
      
      # Collect form data for each check-in
      check_in_data = {}
      ready_check_ins.each do |check_in|
        check_in_id = check_in.id
        assignment_id = check_in.assignment.id
        Rails.logger.info "BULK_FINALIZE: 8 - Processing check-in #{check_in_id} for assignment #{assignment_id} (#{check_in.assignment.title})"
        
        # Try both formats: check_in_#{check_in_id}_* and check_in_#{assignment_id}_*
        final_rating = params["check_in_#{check_in_id}_final_rating"] || params["check_in_#{assignment_id}_final_rating"]
        shared_notes = params["check_in_#{check_in_id}_shared_notes"] || params["check_in_#{assignment_id}_shared_notes"]
        close_rating = params["check_in_#{check_in_id}_close_rating"] == 'true' || params["check_in_#{assignment_id}_close_rating"] == 'true'
        
        check_in_data[assignment_id] = {
          check_in_id: check_in_id,
          final_rating: final_rating,
          shared_notes: shared_notes,
          close_rating: close_rating
        }
        
        Rails.logger.info "BULK_FINALIZE: 9 - Check-in #{check_in_id} (assignment #{assignment_id}) data: #{check_in_data[assignment_id].inspect}"
      end
      
      # Capture security information
      request_info = {
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        session_id: session.id,
        request_id: SecureRandom.uuid,
        timestamp: Time.current
      }
      Rails.logger.info "BULK_FINALIZE: 10 - Request info captured: #{request_info.inspect}"
      
      # Determine the real user (admin) vs impersonated user
      real_user = session[:impersonating_person_id] ? Person.find(session[:impersonating_person_id]) : current_person
      Rails.logger.info "BULK_FINALIZE: 11 - Real user determined: #{real_user.id} (#{real_user.full_name})"
      
      # Step 1: Build MaapSnapshot without maap_data
      Rails.logger.info "BULK_FINALIZE: 12 - Building MaapSnapshot without maap_data with form_params keys: #{params.keys.inspect}"
      maap_snapshot = MaapSnapshot.build_for_employee_without_maap_data(
        employee: @person,
        created_by: real_user,
        change_type: 'bulk_check_in_finalization',
        reason: 'Bulk finalization of ready check-ins',
        request_info: request_info,
        form_params: params.merge(return_to_check_ins: true, check_in_data: check_in_data, original_organization_id: @organization.id)
      )
      
      if maap_snapshot.save
        Rails.logger.info "BULK_FINALIZE: 13 - MaapSnapshot saved without maap_data, ID: #{maap_snapshot.id}"
        
        # Step 2: Process the snapshot with the processor
        Rails.logger.info "BULK_FINALIZE: 14 - Processing snapshot with BulkCheckInFinalizationProcessor"
        maap_snapshot.process_with_processor!
        Rails.logger.info "BULK_FINALIZE: 15 - MaapSnapshot processed successfully, maap_data built"
        
        # Step 3: Redirect to execute changes
        Rails.logger.info "BULK_FINALIZE: 16 - Redirecting to execute changes"
        redirect_to execute_changes_organization_person_path(@organization, @person, maap_snapshot), 
                    notice: "Bulk check-in finalization queued for processing. Review and execute below. #{@person&.full_name} - #{maap_snapshot&.id}"
      else
        Rails.logger.error "BULK_FINALIZE: 17 - MaapSnapshot save failed: #{maap_snapshot.errors.full_messages}"
        redirect_to organization_check_in_path(@organization, @person), 
                    alert: 'Failed to create change record. Please try again.'
      end
    else
      Rails.logger.info "BULK_FINALIZE: 17 - No check-ins ready for finalization, redirecting with alert"
      redirect_to organization_check_in_path(@organization, @person), 
                  alert: 'No check-ins are ready for finalization. Both employee and manager must complete their sections first.'
    end
  end


  private

  def set_person
    @person = Person.find(params[:id])
  end

  def load_check_in_data
    # Get check-ins that have at least one side completed (employee or manager)
    # Filter by assignments within the current organization
    # Only show in-progress check-ins (exclude completed ones)
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
      .where(official_check_in_completed_at: nil) # Exclude completed check-ins
      .includes(:assignment)
      .order(:check_in_started_on)
    
    # Determine what information the current user can see
    @is_employee = current_person == @person
    @is_manager = !@is_employee && policy(@person).can_view_manage_mode?
    @can_see_both_sides = @check_ins_in_progress.any? { |ci| ci.ready_for_finalization? }
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access check-ins.'
    end
  end
end
