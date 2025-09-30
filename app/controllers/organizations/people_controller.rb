class Organizations::PeopleController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_person
  after_action :verify_authorized

  def show
    authorize @person
    # Organization-scoped person view - filtered by the organization from the route
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .where(company: organization)
                                 .order(started_at: :desc)
                                 .decorate
    @assignment_tenures = @person.assignment_tenures.includes(:assignment)
                                 .joins(:assignment)
                                 .where(assignments: { company: organization })
                                 .order(started_at: :desc)
    @person_organization_accesses = @person.person_organization_accesses.includes(:organization)
    
    # Preload huddle associations to avoid N+1 queries
    @person.huddle_participants.includes(:huddle, huddle: :huddle_playbook).load
    @person.huddle_feedbacks.includes(:huddle).load
  end

  def complete_picture
    authorize @person, :manager?
    # Complete picture view - detailed view for managers to see person's position, assignments, and milestones
    # Filter by the organization from the route
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .where(company: organization)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = organization
    
    # Filter assignments to only show those for this organization
    @assignment_tenures = @person.assignment_tenures.active
                                .joins(:assignment)
                                .where(assignments: { company: organization })
                                .includes(:assignment)
    
    # Filter milestones to only show those for abilities in this organization
    @person_milestones = @person.person_milestones
                                .joins(:ability)
                                .where(abilities: { organization: organization })
                                .includes(:ability)
  end

  def teammate
    authorize @person
    # Teammate view - organization-specific data for active employees
    @current_organization = organization
    @employment_tenures = @person.employment_tenures.includes(:company, :position, position: :position_type)
                                 .where(company: organization)
                                 .order(started_at: :desc)
                                 .decorate
    @person_organization_accesses = @person.person_organization_accesses.includes(:organization)
  end

  def check_in
    authorize @person, :manager?
    # Check-In mode - for finalizing assignment check-ins and future 1:1 features
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .where(company: organization)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = organization
    
    # Get assignments ready for finalization (both employee and manager completed)
    @ready_for_finalization = AssignmentCheckIn
      .joins(:assignment)
      .where(person: @person)
      .ready_for_finalization
      .includes(:assignment)
      .order(:check_in_started_on)
  end

  def finalize_check_in
    authorize @person, :manager?
    
    check_in = AssignmentCheckIn.find(params[:check_in_id])
    
    if check_in.ready_for_finalization?
      if params[:final_rating].present?
        check_in.update!(shared_notes: params[:shared_notes])
        check_in.finalize_check_in!(final_rating: params[:final_rating], finalized_by: current_person)
        redirect_to check_in_organization_person_path(organization, @person), notice: 'Check-in finalized successfully.'
      else
        redirect_to check_in_organization_person_path(organization, @person), alert: 'Final rating is required to finalize the check-in.'
      end
    else
      redirect_to check_in_organization_person_path(organization, @person), alert: 'Check-in is not ready for finalization. Both employee and manager must complete their sections first.'
    end
  end

  def execute_changes
    # Authorize the action using Pundit
    authorize @person, :manager?
    
    # Find the maap_snapshot first
    begin
      snapshot = maap_snapshot
    rescue ActiveRecord::RecordNotFound => e
      redirect_to organization_assignment_tenure_path(organization, @person), 
                  alert: 'MaapSnapshot not found. Please try again.'
      return
    end
    
    # Check if current user is the creator of the MaapSnapshot
    unless snapshot.created_by == current_person
      redirect_to organization_assignment_tenure_path(organization, @person), 
                  alert: 'You are not authorized to view this MaapSnapshot.'
      return
    end
    
    # Load current MAAP data and assignment data for comparison
    @current_organization = organization
    load_current_maap_data
    load_assignments_and_check_ins
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "RecordNotFound: #{e.message}"
    redirect_to organization_assignment_tenure_path(organization, @person), 
                alert: 'MaapSnapshot not found. Please try again.'
  rescue => e
    Rails.logger.error "Error in execute_changes: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5)}"
    redirect_to organization_assignment_tenure_path(organization, @person), 
                alert: 'An error occurred. Please try again.'
  end

  def process_changes
    # Authorize the action using Pundit
    authorize @person, :manager?
    
    # Check if current user is the creator of the MaapSnapshot
    unless maap_snapshot.created_by == current_person
      redirect_to organization_assignment_tenure_path(organization, @person), 
                  alert: 'You are not authorized to execute this MaapSnapshot.'
      return
    end
    
    # Update reason if provided
    if params[:reason].present?
      maap_snapshot.update!(reason: params[:reason])
    end
    
    # Execute the changes
    if execute_maap_changes!
      maap_snapshot.update!(effective_date: Date.current)

      # Redirect based on change type and return_to_check_ins parameter
      Rails.logger.info "BULK_FINALIZE: 18 - Processing redirect in Organizations::PeopleController#process_changes"
      Rails.logger.info "BULK_FINALIZE: 19 - Current person: #{current_person.id} (#{current_person.full_name})"
      Rails.logger.info "BULK_FINALIZE: 20 - Impersonation session: #{session[:impersonating_person_id]}"
      Rails.logger.info "BULK_FINALIZE: 21 - MaapSnapshot change_type: #{maap_snapshot.change_type}"
      Rails.logger.info "BULK_FINALIZE: 22 - Return to check-ins: #{maap_snapshot.form_params&.dig('return_to_check_ins')}"
      Rails.logger.info "BULK_FINALIZE: 23 - Original org ID: #{maap_snapshot.form_params&.dig('original_organization_id')}"
      
      redirect_path = if maap_snapshot.form_params&.dig('return_to_check_ins') == 'true'
        original_org_id = maap_snapshot.form_params&.dig('original_organization_id')
        redirect_org = original_org_id ? Organization.find(original_org_id) : organization
        Rails.logger.info "BULK_FINALIZE: 24 - Using organization for redirect: #{redirect_org.id} (#{redirect_org.name})"
        check_in_organization_person_path(redirect_org, @person)
      else
        case maap_snapshot.change_type
        when 'assignment_management'
          organization_assignment_tenure_path(organization, @person)
        when 'bulk_check_in_finalization', 'individual_check_in_finalization'
          check_in_organization_person_path(organization, @person)
        when 'position_tenure'
          organization_person_path(organization, @person) # TODO: Update when position tenure page exists
        when 'milestone_management'
          organization_person_path(organization, @person) # TODO: Update when milestone management page exists
        when 'aspiration_management'
          organization_person_path(organization, @person) # TODO: Update when aspiration management page exists
        when 'exploration'
          organization_person_path(organization, @person) # TODO: Update when exploration results page exists
        else
          organization_person_path(organization, @person)
        end
      end

      Rails.logger.info "BULK_FINALIZE: 25 - Final redirect path: #{redirect_path}"
      redirect_to redirect_path, notice: 'Changes executed successfully!'
    else
      redirect_to execute_changes_organization_person_path(organization, @person, maap_snapshot),
                  alert: 'Failed to execute changes. Please review and try again.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to organization_assignment_tenure_path(organization, @person), 
                alert: 'MaapSnapshot not found. Please try again.'
  rescue Pundit::NotAuthorizedError
    redirect_to organization_assignment_tenure_path(organization, @person), 
                alert: 'You are not authorized to execute changes for this person.'
  rescue => e
    Rails.logger.error "Error in process_changes: #{e.message}"
    redirect_to organization_assignment_tenure_path(organization, @person), 
                alert: 'An error occurred while processing changes. Please try again.'
  end

  def update_permission
    authorize @person, :manager?
    
    permission_type = params[:permission_type]
    permission_value = params[:permission_value]
    org = organization
    
    # Find or create the person organization access record
    access = @person.person_organization_accesses.find_or_initialize_by(organization: org)
    
    # Update the specific permission
    case permission_type
    when 'can_manage_employment'
      access.can_manage_employment = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    when 'can_create_employment'
      access.can_create_employment = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    when 'can_manage_maap'
      access.can_manage_maap = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    else
      redirect_to organization_person_path(org, @person), alert: 'Invalid permission type.'
      return
    end
    
    # Save the access record
    if access.save
      redirect_to organization_person_path(org, @person), notice: 'Permission updated successfully.'
    else
      redirect_to organization_person_path(org, @person), alert: 'Failed to update permission.'
    end
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def maap_snapshot
    @maap_snapshot ||= MaapSnapshot.find(params[:maap_snapshot_id])
  end

  def load_current_maap_data
    # Load current MAAP data for comparison
    @current_employment = @person.employment_tenures.active.first
    @current_assignments = @person.assignment_tenures.active.includes(:assignment)
    @current_milestones = @person.person_milestones.includes(:ability)
    @current_maap_data = {
      assignments: @person.assignment_tenures.active.includes(:assignment),
      check_ins: AssignmentCheckIn.where(person: @person).includes(:assignment),
      milestones: @person.person_milestones.includes(:ability),
      aspirations: organization.aspirations.includes(:ability) # Aspirations belong to organization, not person
    }
  end

  def load_assignments_and_check_ins
    # Load assignments where the person has ever had a tenure, filtered by organization
    assignment_ids = @person.assignment_tenures.distinct.pluck(:assignment_id)
    assignments = Assignment.where(id: assignment_ids, company: organization).includes(:assignment_tenures)
    
    @assignment_data = assignments.map do |assignment|
      active_tenure = @person.assignment_tenures.where(assignment: assignment).active.first
      most_recent_tenure = @person.assignment_tenures.where(assignment: assignment).order(:started_at).last
      open_check_in = AssignmentCheckIn.where(person: @person, assignment: assignment).open.first
      
      {
        assignment: assignment,
        active_tenure: active_tenure,
        most_recent_tenure: most_recent_tenure,
        open_check_in: open_check_in
      }
    end.sort_by { |data| -(data[:active_tenure]&.anticipated_energy_percentage || 0) }
    
    # Load assignments and check-ins for the organization
    @assignments = @person.assignment_tenures.active
                         .joins(:assignment)
                         .where(assignments: { company: organization })
                         .includes(:assignment)
    
    @check_ins = AssignmentCheckIn.joins(:assignment)
                                  .where(person: @person, assignments: { company: organization })
                                  .includes(:assignment)
  end

  def execute_maap_changes!
    service = MaapChangeExecutionService.new(
      maap_snapshot: maap_snapshot,
      current_user: current_person
    )
    service.execute!
  end

  # Helper methods for execute_changes view
  helper_method :can_see_manager_private_data?, :can_see_employee_private_data?, :format_private_field_value, :employment_has_changes?, :assignment_has_changes?, :milestone_has_changes?, :check_in_has_changes?, :can_see_manager_private_notes?, :person
  
  def assignment_has_changes?(assignment)
    change_detection_service.assignment_has_changes?(assignment)
  end

  def change_detection_service
    @change_detection_service ||= MaapChangeDetectionService.new(person: @person, maap_snapshot: @maap_snapshot, current_user: current_person)
  end

  def can_see_manager_private_data?(employee)
    # Only allow managers of other people to see manager private data
    # Exclude the case where current_person == employee (employees can't see their own manager data)
    return false if current_person == employee
    
    policy(employee).manager?
  end

  def can_see_employee_private_data?(employee)
    current_person == employee
  end

  def format_private_field_value(value, can_see, employee_name, field_type)
    if can_see
      value.present? ? value : '<not set>'
    else
      if field_type == 'manager'
        "<only visible to #{employee_name}'s managers>"
      else
        "<only visible to #{employee_name}>"
      end
    end
  end

  def admin_bypass?
    current_person&.og_admin?
  end

  private

  def employment_has_changes?
    return false unless maap_snapshot&.maap_data&.dig('employment_tenure')
    
    current = @current_employment
    proposed = maap_snapshot.maap_data['employment_tenure']
    
    return true unless current
    
    current.position_id.to_s != proposed['position_id'].to_s ||
    current.manager_id.to_s != proposed['manager_id'].to_s ||
    current.started_at.to_date != Date.parse(proposed['started_at']) ||
    current.seat_id.to_s != proposed['seat_id'].to_s
  end

  def check_in_has_changes?(assignment, proposed_data)
    current_check_in = AssignmentCheckIn.where(person: @person, assignment: assignment).open.first
    
    # Only check for changes in fields the current user is authorized to modify
    
    # Check employee check-in changes (only if current user can update employee fields)
    if proposed_data['employee_check_in'] && can_update_employee_check_in_fields?(current_check_in)
      employee_changed = if current_check_in
        current_check_in.actual_energy_percentage != proposed_data['employee_check_in']['actual_energy_percentage'] ||
        current_check_in.employee_rating != proposed_data['employee_check_in']['employee_rating'] ||
        current_check_in.employee_private_notes != proposed_data['employee_check_in']['employee_private_notes'] ||
        current_check_in.employee_personal_alignment != proposed_data['employee_check_in']['employee_personal_alignment'] ||
        (current_check_in.employee_completed? || false) != proposed_data['employee_check_in']['employee_completed_at'].present?
      else
        proposed_data['employee_check_in'].values.any? { |v| v.present? }
      end
      return true if employee_changed
    end
    
    # Check manager check-in changes (only if current user can update manager fields)
    if proposed_data['manager_check_in'] && can_update_manager_check_in_fields?(current_check_in)
      manager_changed = if current_check_in
        current_check_in.manager_rating != proposed_data['manager_check_in']['manager_rating'] ||
        current_check_in.manager_private_notes != proposed_data['manager_check_in']['manager_private_notes'] ||
        (current_check_in.manager_completed? || false) != proposed_data['manager_check_in']['manager_completed_at'].present? ||
        current_check_in.manager_completed_by_id.to_s != proposed_data['manager_check_in']['manager_completed_by_id'].to_s
      else
        proposed_data['manager_check_in'].values.any? { |v| v.present? }
      end
      return true if manager_changed
    end
    
    # Check official check-in changes (only if current user can finalize)
    if proposed_data['official_check_in'] && can_finalize_check_in?(current_check_in)
      official_changed = if current_check_in
        current_check_in.official_rating != proposed_data['official_check_in']['official_rating'] ||
        current_check_in.shared_notes != proposed_data['official_check_in']['shared_notes'] ||
        (current_check_in.officially_completed? || false) != proposed_data['official_check_in']['official_check_in_completed_at'].present? ||
        current_check_in.finalized_by_id.to_s != proposed_data['official_check_in']['finalized_by_id'].to_s
      else
        proposed_data['official_check_in'].values.any? { |v| v.present? }
      end
      return true if official_changed
    end
    
    false
  end

  def milestone_has_changes?(milestone)
    return false unless maap_snapshot&.maap_data&.dig('milestones')
    
    proposed_data = maap_snapshot.maap_data['milestones'].find { |m| m['ability_id'] == milestone.ability_id }
    return false unless proposed_data
    
    milestone.milestone_level != proposed_data['milestone_level'] ||
    milestone.certified_by_id.to_s != proposed_data['certified_by_id'].to_s ||
    milestone.attained_at.to_s != proposed_data['attained_at'].to_s
  end

  def can_see_manager_private_notes?
    # Only managers and the person themselves can see manager private notes
    current_person == @person || authorize(@person, :manager?, policy_class: PersonPolicy)
  rescue Pundit::NotAuthorizedError
    false
  end

  def person
    @person
  end

end
