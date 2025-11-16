class PeopleController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_login, except: [:public]
  before_action :authorize_maap_snapshot_actions
  after_action :verify_authorized
  
  helper_method :real_current_person, :person, :maap_snapshot


  def show
    authorize person, :view_check_ins?, policy_class: PersonPolicy
    # Get all employment tenures across all organizations through teammates
    @employment_tenures = EmploymentTenure.joins(:teammate)
                                        .where(teammates: { person: person })
                                        .includes(:company, :position, :manager)
                                        .order(started_at: :desc)
                                        .decorate
    # Get all assignment tenures across all organizations through teammates
    @assignment_tenures = AssignmentTenure.joins(:teammate)
                                         .where(teammates: { person: person })
                                         .includes(:assignment)
                                         .order(started_at: :desc)
    @teammates = person.teammates.includes(:organization)
    
    # Preload huddle associations to avoid N+1 queries
    HuddleParticipant.joins(:teammate)
                    .where(teammates: { person: person })
                    .includes(:huddle, huddle: :huddle_playbook)
                    .load
    HuddleFeedback.joins(:teammate)
                  .where(teammates: { person: person })
                  .includes(:huddle)
                  .load
  end

  def public
    authorize person, policy_class: PersonPolicy
    # Public view - showcase public observations and milestones across all organizations
    # Use unauthenticated layout
    render layout: 'application'
    
    # Get all public observations where this person is observed
    teammate_ids = person.teammates.pluck(:id)
    @public_observations = if teammate_ids.any?
      Observation.public_observations
        .joins(:observees)
        .where(observees: { teammate_id: teammate_ids })
        .published
        .includes(:observer, :observed_teammates)
        .order(observed_at: :desc)
        .decorate
    else
      Observation.none.decorate
    end
    
    # Get all milestones across all organizations
    @milestones = if person.teammates.exists?
      TeammateMilestone.joins(:teammate)
        .where(teammates: { person: person })
        .includes(:ability, :certified_by)
        .order(attained_at: :desc)
    else
      TeammateMilestone.none
    end
  end

  def update
    authorize person, policy_class: PersonPolicy
    if person.update(person_params)
      redirect_to profile_path, notice: 'Profile updated successfully!'
    else
      capture_error_in_sentry(ActiveRecord::RecordInvalid.new(person), {
        method: 'update_profile',
        person_id: person.id,
        validation_errors: person.errors.full_messages
      })
      setup_show_instance_variables
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Handle unique constraint violations (like duplicate phone numbers)
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: person&.id,
      error_type: 'unique_constraint_violation'
    })
    person.errors.add(:unique_textable_phone_number, 'is already taken by another user')
    setup_show_instance_variables
    render :show, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    # Handle other database constraint violations
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: person&.id,
      error_type: 'database_constraint_violation'
    })
    person.errors.add(:base, 'Unable to update profile due to a database constraint. Please try again.')
    setup_show_instance_variables
    render :show, status: :unprocessable_entity
  rescue => e
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: person&.id
    })
    person.errors.add(:base, 'An unexpected error occurred while updating your profile. Please try again.')
    setup_show_instance_variables
    render :show, status: :unprocessable_entity
  end

  def connect_google_identity
    authorize person, policy_class: PersonPolicy
    redirect_to "/auth/google_oauth2", data: { turbo: false }
  end

  def disconnect_identity
    authorize person, policy_class: PersonPolicy
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

  def setup_show_instance_variables
    # Get all employment tenures across all organizations through teammates
    @employment_tenures = EmploymentTenure.joins(:teammate)
                                        .where(teammates: { person: person })
                                        .includes(:company, :position, :manager)
                                        .order(started_at: :desc)
                                        .decorate
    # Get all assignment tenures across all organizations through teammates
    @assignment_tenures = AssignmentTenure.joins(:teammate)
                                         .where(teammates: { person: person })
                                         .includes(:assignment)
                                         .order(started_at: :desc)
    @teammates = person.teammates.includes(:organization)
    
    # Preload huddle associations to avoid N+1 queries
    HuddleParticipant.joins(:teammate)
                    .where(teammates: { person: person })
                    .includes(:huddle, huddle: :huddle_playbook)
                    .load
    HuddleFeedback.joins(:teammate)
                  .where(teammates: { person: person })
                  .includes(:huddle)
                  .load
  end

  def maap_snapshot
    return @maap_snapshot if @maap_snapshot
    @maap_snapshot = MaapSnapshot.find(params[:maap_snapshot_id]) if params[:maap_snapshot_id].present?
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access your profile'
    end
  end

  def load_assignments_and_check_ins
    # Load assignments where the person has ever had a tenure across all organizations
    assignment_ids = AssignmentTenure.joins(:teammate)
                                   .where(teammates: { person: person })
                                   .distinct
                                   .pluck(:assignment_id)
    assignments = Assignment.where(id: assignment_ids).includes(:assignment_tenures)
    
    @assignment_data = assignments.map do |assignment|
      # Find teammate for this assignment's company
      teammate = person.teammates.find_by(organization: assignment.company)
      next unless teammate
      
      active_tenure = teammate.assignment_tenures.where(assignment: assignment).active.first
      most_recent_tenure = teammate.assignment_tenures.where(assignment: assignment).order(:started_at).last
      open_check_in = AssignmentCheckIn.where(teammate: teammate, assignment: assignment).open.first
      
      {
        assignment: assignment,
        active_tenure: active_tenure,
        most_recent_tenure: most_recent_tenure,
        open_check_in: open_check_in
      }
    end.compact.sort_by { |data| -(data[:active_tenure]&.anticipated_energy_percentage || 0) }
  end

  def load_current_maap_data(organization)
    teammate = person.teammates.find_by(organization: organization)
    return unless teammate
    
    @current_employment = teammate.employment_tenures.active.first
    @current_assignments = teammate.assignment_tenures.active.includes(:assignment)
    @current_milestones = teammate.teammate_milestones.includes(:ability)
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
    teammate = person.teammates.find_by(organization: assignment.company)
    current_check_in = teammate ? AssignmentCheckIn.where(teammate: teammate, assignment: assignment).open.first : nil
    
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
    current_person == person || authorize(person, :manager?, policy_class: PersonPolicy)
  rescue Pundit::NotAuthorizedError
    false
  end

  helper_method :employment_has_changes?, :assignment_has_changes?, :milestone_has_changes?, :check_in_has_changes?, :can_see_manager_private_notes?

  def change_detection_service
    @change_detection_service ||= MaapChangeDetectionService.new(person: person, maap_snapshot: maap_snapshot, current_user: current_company_teammate)
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
    teammate = person.teammates.find_by(organization: assignment.company)
    check_in = teammate ? AssignmentCheckIn.where(teammate: teammate, assignment: assignment).open.first : nil
    
    if check_in
      # Update existing check-in
      update_check_in_fields(check_in, check_in_data)
    else
      # Create new check-in
      # Find teammate for this person and assignment's company
      teammate = person.teammates.find_by(organization: assignment.company)
      
      check_in = AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
      update_check_in_fields(check_in, check_in_data)
    end
  end

  def update_check_in_fields(check_in, check_in_data)
    # Only update fields that the current user is authorized to modify
    # This prevents concurrent updates from overwriting each other
    
    # Update employee check-in fields (only if current user is the employee)
    if check_in_data['employee_check_in'] && can_update_employee_check_in_fields?(check_in)
      update_employee_check_in_fields(check_in, check_in_data['employee_check_in'])
    end
    
    # Update manager check-in fields (only if current user is authorized manager)
    if check_in_data['manager_check_in'] && can_update_manager_check_in_fields?(check_in)
      update_manager_check_in_fields(check_in, check_in_data['manager_check_in'])
    end
    
    # Update official check-in fields (only if current user can finalize)
    if check_in_data['official_check_in'] && can_finalize_check_in?(check_in)
      update_official_check_in_fields(check_in, check_in_data['official_check_in'])
    end
  end

  def admin_bypass?
    current_person&.og_admin?
  end

  private

  def can_update_employee_check_in_fields?(check_in)
    # Employee can update their own check-in fields
    current_person == check_in.teammate.person || admin_bypass?
  end

  def can_update_manager_check_in_fields?(check_in)
    # Manager can update manager fields if they have management permissions
    return true if admin_bypass?
    
    # Employee cannot update their own manager fields
    return false if current_person == check_in.teammate.person
    
    # Check if current user can manage this person's assignments
    policy(check_in.teammate.person).manage_assignments?
  end

  def can_finalize_check_in?(check_in)
    # Only managers can finalize check-ins
    return true if admin_bypass?
    
    # Check if current user can manage this person's assignments
    policy(check_in.teammate.person).manage_assignments?
  end

  def update_employee_check_in_fields(check_in, employee_data)
    check_in.update!(
      actual_energy_percentage: employee_data['actual_energy_percentage'],
      employee_rating: employee_data['employee_rating'],
      employee_private_notes: employee_data['employee_private_notes'],
      employee_personal_alignment: employee_data['employee_personal_alignment']
    )
    
    if employee_data['employee_completed_at']
      check_in.complete_employee_side!
    end
  end

  def update_manager_check_in_fields(check_in, manager_data)
    check_in.update!(
      manager_rating: manager_data['manager_rating'],
      manager_private_notes: manager_data['manager_private_notes']
    )
    
    if manager_data['manager_completed_at']
      check_in.complete_manager_side!(completed_by: current_person)
    end
  end

  def update_official_check_in_fields(check_in, official_data)
    check_in.update!(
      official_rating: official_data['official_rating'],
      shared_notes: official_data['shared_notes']
    )
    
    if official_data['official_check_in_completed_at']
      check_in.finalize_check_in!(final_rating: official_data['official_rating'], finalized_by: current_person)
    end
  end

  def authorize_maap_snapshot_actions
    # Only authorize for MAAP snapshot actions
    return unless %w[execute_changes process_changes].include?(action_name)
    
    # Ensure person is available before authorization
    return unless person.present?
    
    authorize person, :manager?, policy_class: PersonPolicy
  end

  # Helper methods for execute_changes view
  helper_method :can_see_manager_private_data?, :can_see_employee_private_data?, :format_private_field_value
  
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

  def person_params
    params.require(:person).permit(:first_name, :last_name, :middle_name, :suffix, 
                                  :unique_textable_phone_number, :timezone,
                                  :preferred_name, :gender_identity, :pronouns)
  end
end 