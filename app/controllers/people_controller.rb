class PeopleController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_login, except: [:public]
  before_action :authorize_maap_snapshot_actions
  after_action :verify_authorized, except: [:index]
  after_action :verify_policy_scoped, only: :index
  
  helper_method :real_current_person, :person, :maap_snapshot

  def index
    authorize Person
    @people = policy_scope(Person).includes(:employment_tenures, :huddles)
                    .order(:first_name, :last_name)
                    .decorate
  end

  def show
    authorize person
    @employment_tenures = person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
    @assignment_tenures = person.assignment_tenures.includes(:assignment)
                                 .order(started_at: :desc)
    @person_organization_accesses = person.person_organization_accesses.includes(:organization)
    
    # Preload huddle associations to avoid N+1 queries
    person.huddle_participants.includes(:huddle, huddle: :huddle_playbook).load
    person.huddle_feedbacks.includes(:huddle).load
  end

  def public
    authorize person
    # Public view - minimal data, no sensitive information
    @employment_tenures = person.employment_tenures.includes(:company)
                                 .order(started_at: :desc)
                                 .decorate
  end

  def teammate
    authorize person
    # Teammate view - organization-specific data for active employees
    @current_organization = current_person&.current_organization
    @employment_tenures = person.employment_tenures.includes(:company, :position, position: :position_type)
                                 .order(started_at: :desc)
                                 .decorate
    @person_organization_accesses = person.person_organization_accesses.includes(:organization)
  end

  def growth
    authorize person, :manager?
    # Growth view - detailed view for managers to see person's position, assignments, and milestones
    @employment_tenures = person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = @current_employment&.company
  end

  def check_in
    authorize person, :manager?
    # Check-In mode - for finalizing assignment check-ins and future 1:1 features
    @employment_tenures = person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = @current_employment&.company
    
    # Get assignments ready for finalization (both employee and manager completed)
    @ready_for_finalization = AssignmentCheckIn
      .joins(:assignment)
      .where(person: person)
      .ready_for_finalization
      .includes(:assignment)
      .order(:check_in_started_on)
  end


  def finalize_check_in
    authorize person, :manager?
    
    check_in = AssignmentCheckIn.find(params[:check_in_id])
    
    if check_in.ready_for_finalization?
      if params[:final_rating].present?
        check_in.update!(shared_notes: params[:shared_notes])
        check_in.finalize_check_in!(final_rating: params[:final_rating], finalized_by: current_person)
        redirect_to check_in_person_path(person), notice: 'Check-in finalized successfully.'
      else
        redirect_to check_in_person_path(person), alert: 'Final rating is required to finalize the check-in.'
      end
    else
      redirect_to check_in_person_path(person), alert: 'Check-in is not ready for finalization. Both employee and manager must complete their sections first.'
    end
  end



  def edit
    authorize person
  end

  def update
    authorize person
    if person.update(person_params)
      redirect_to profile_path, notice: 'Profile updated successfully!'
    else
      capture_error_in_sentry(ActiveRecord::RecordInvalid.new(person), {
        method: 'update_profile',
        person_id: person.id,
        validation_errors: person.errors.full_messages
      })
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Handle unique constraint violations (like duplicate phone numbers)
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: person&.id,
      error_type: 'unique_constraint_violation'
    })
    person.errors.add(:unique_textable_phone_number, 'is already taken by another user')
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    # Handle other database constraint violations
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: person&.id,
      error_type: 'database_constraint_violation'
    })
    person.errors.add(:base, 'Unable to update profile due to a database constraint. Please try again.')
    render :edit, status: :unprocessable_entity
  rescue => e
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: person&.id
    })
    person.errors.add(:base, 'An unexpected error occurred while updating your profile. Please try again.')
    render :edit, status: :unprocessable_entity
  end

  def connect_google_identity
    authorize person
    redirect_to "/auth/google_oauth2", data: { turbo: false }
  end

  def disconnect_identity
    authorize person
    identity = person.person_identities.find(params[:id])
    
    unless person.can_disconnect_identity?(identity)
      redirect_to profile_path, alert: 'Cannot disconnect this account. Please add another Google account first.'
      return
    end
    
    if identity.destroy
      redirect_to profile_path, notice: 'Account disconnected successfully!'
    else
      redirect_to profile_path, alert: 'Failed to disconnect account. Please try again.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to profile_path, alert: 'Account not found.'
  end

  def person
    @person ||= if params[:id].present?
                  Person.find(params[:id])
                else
                  current_person
                end
  end

  def maap_snapshot
    return @maap_snapshot if @maap_snapshot
    @maap_snapshot = MaapSnapshot.find(params[:maap_snapshot_id]) if params[:maap_snapshot_id].present?
  end

  def execute_changes
    # Check if current user is the creator of the MaapSnapshot
    unless maap_snapshot.created_by == current_person
      redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
                  alert: 'You are not authorized to view this MaapSnapshot.'
      return
    end
    
    # Load current MAAP data and assignment data for comparison
    load_current_maap_data
    load_assignments_and_check_ins
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "RecordNotFound: #{e.message}"
    redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
                alert: 'MaapSnapshot not found. Please try again.'
  rescue => e
    Rails.logger.error "Error in execute_changes: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5)}"
    redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
                alert: 'An error occurred. Please try again.'
  end

  def process_changes
    # Check if current user is the creator of the MaapSnapshot
    unless maap_snapshot.created_by == current_person
      redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
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

      # Redirect based on change type
      redirect_path = case maap_snapshot.change_type
      when 'assignment_management'
        organization_assignment_tenure_path(person.current_organization_or_default, person)
      when 'position_tenure'
        person_path(person) # TODO: Update when position tenure page exists
      when 'milestone_management'
        person_path(person) # TODO: Update when milestone management page exists
      when 'aspiration_management'
        person_path(person) # TODO: Update when aspiration management page exists
      when 'exploration'
        person_path(person) # TODO: Update when exploration results page exists
      else
        person_path(person)
      end

      redirect_to redirect_path, notice: 'Changes executed successfully!'
    else
      redirect_to execute_changes_person_path(person, maap_snapshot),
                  alert: 'Failed to execute changes. Please review and try again.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
                alert: 'MaapSnapshot not found. Please try again.'
  rescue Pundit::NotAuthorizedError
    redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
                alert: 'You are not authorized to execute changes for this person.'
  rescue => e
    Rails.logger.error "Error in process_changes: #{e.message}"
    redirect_to organization_assignment_tenure_path(person.current_organization_or_default, person), 
                alert: 'An error occurred while processing changes. Please try again.'
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access your profile'
    end
  end

  def load_assignments_and_check_ins
    # Load assignments where the person has ever had a tenure
    assignment_ids = person.assignment_tenures.distinct.pluck(:assignment_id)
    assignments = Assignment.where(id: assignment_ids).includes(:assignment_tenures)
    
    @assignment_data = assignments.map do |assignment|
      active_tenure = person.assignment_tenures.where(assignment: assignment).active.first
      most_recent_tenure = person.assignment_tenures.where(assignment: assignment).order(:started_at).last
      open_check_in = AssignmentCheckIn.where(person: person, assignment: assignment).open.first
      
      {
        assignment: assignment,
        active_tenure: active_tenure,
        most_recent_tenure: most_recent_tenure,
        open_check_in: open_check_in
      }
    end.sort_by { |data| -(data[:active_tenure]&.anticipated_energy_percentage || 0) }
  end

  def load_current_maap_data
    @current_employment = person.employment_tenures.active.first
    @current_assignments = person.assignment_tenures.active.includes(:assignment)
    @current_milestones = person.person_milestones.includes(:ability)
    @current_aspirations = [] # TODO: Implement when aspiration model exists
  end

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

  def assignment_has_changes?(assignment)
    change_detection_service.assignment_has_changes?(assignment)
  end

  def check_in_has_changes?(assignment, proposed_data)
    current_check_in = AssignmentCheckIn.where(person: person, assignment: assignment).open.first
    
    # Check employee check-in changes
    if proposed_data['employee_check_in']
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
    
    # Check manager check-in changes
    if proposed_data['manager_check_in']
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
    
    # Check official check-in changes
    if proposed_data['official_check_in']
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
    current_person == person || authorize(person, :manager?, policy_class: PersonPolicy)
  rescue Pundit::NotAuthorizedError
    false
  end

  helper_method :employment_has_changes?, :assignment_has_changes?, :milestone_has_changes?, :check_in_has_changes?, :can_see_manager_private_notes?

  def change_detection_service
    @change_detection_service ||= MaapChangeDetectionService.new(person: person, maap_snapshot: maap_snapshot)
  end

  def execute_maap_changes!
    begin
      # Execute assignment changes
      if maap_snapshot.maap_data['assignments']
        execute_assignment_changes
      end
      
      # TODO: Execute other change types (position, milestone, aspiration)
      
      true
    rescue => e
      Rails.logger.error "Failed to execute MAAP changes: #{e.message}"
      false
    end
  end

  def execute_assignment_changes
    maap_snapshot.maap_data['assignments'].each do |assignment_data|
      assignment = Assignment.find(assignment_data['id'])
      
      # Update tenure
      if assignment_data['tenure']
        update_assignment_tenure(assignment, assignment_data['tenure'])
      end
      
      # Update check-in
      if assignment_data['employee_check_in'] || assignment_data['manager_check_in'] || assignment_data['official_check_in']
        update_assignment_check_in(assignment, assignment_data)
      end
    end
  end

  def update_assignment_tenure(assignment, tenure_data)
    service = AssignmentTenureService.new(
      person: person,
      assignment: assignment,
      created_by: current_person
    )

    service.update_tenure(
      anticipated_energy_percentage: tenure_data['anticipated_energy_percentage'],
      started_at: tenure_data['started_at']
    )
  end

  def update_assignment_check_in(assignment, check_in_data)
    check_in = AssignmentCheckIn.where(person: person, assignment: assignment).open.first
    
    if check_in
      # Update existing check-in
      update_check_in_fields(check_in, check_in_data)
    else
      # Create new check-in
      check_in = AssignmentCheckIn.create!(
        person: person,
        assignment: assignment,
        check_in_started_on: Date.current
      )
      update_check_in_fields(check_in, check_in_data)
    end
  end

  def update_check_in_fields(check_in, check_in_data)
    # Update employee check-in fields
    if check_in_data['employee_check_in']
      employee_data = check_in_data['employee_check_in']
      check_in.update!(
        actual_energy_percentage: employee_data['actual_energy_percentage'],
        employee_rating: employee_data['employee_rating'],
        employee_private_notes: employee_data['employee_private_notes'],
        employee_personal_alignment: employee_data['employee_personal_alignment']
      )
      
      if employee_data['employee_completed_at']
        check_in.complete_employee_side!(completed_by: current_person)
      end
    end
    
    # Update manager check-in fields
    if check_in_data['manager_check_in']
      manager_data = check_in_data['manager_check_in']
      check_in.update!(
        manager_rating: manager_data['manager_rating'],
        manager_private_notes: manager_data['manager_private_notes']
      )
      
      if manager_data['manager_completed_at']
        check_in.complete_manager_side!(completed_by: current_person)
      end
    end
    
    # Update official check-in fields
    if check_in_data['official_check_in']
      official_data = check_in_data['official_check_in']
      check_in.update!(
        official_rating: official_data['official_rating'],
        shared_notes: official_data['shared_notes']
      )
      
      if official_data['official_check_in_completed_at']
        check_in.finalize_check_in!(finalized_by: current_person)
      end
    end
  end

  def authorize_maap_snapshot_actions
    # Only authorize for MAAP snapshot actions
    return unless %w[execute_changes process_changes].include?(action_name)
    
    authorize person, :manager?, policy_class: PersonPolicy
  end

  # Helper methods for execute_changes view
  helper_method :can_see_manager_private_data?, :can_see_employee_private_data?, :format_private_field_value
  
  def can_see_manager_private_data?(employee)
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

  def person_params
    params.require(:person).permit(:first_name, :last_name, :middle_name, :suffix, 
                                  :email, :unique_textable_phone_number, :timezone)
  end
end 