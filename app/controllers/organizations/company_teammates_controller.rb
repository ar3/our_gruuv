class Organizations::CompanyTeammatesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    # Organization-scoped teammate view - filtered by the organization from the route
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :position, :manager)
                                 &.where(company: organization)
                                 &.order(started_at: :desc)
                                 &.decorate || []
    @assignment_tenures = @teammate&.assignment_tenures&.includes(:assignment)
                                 &.joins(:assignment)
                                 &.where(assignments: { company: organization })
                                 &.order(started_at: :desc) || []
    @teammates = @teammate.person.teammates.includes(:organization)
    @teammate_identities = @teammate&.teammate_identities || []

    # Preload huddle associations to avoid N+1 queries
    HuddleParticipant.joins(:teammate)
                    .where(teammates: { id: @teammate.id, organization: organization })
                    .includes(:huddle, huddle: :huddle_playbook)
                    .load
    HuddleFeedback.joins(:teammate)
                  .where(teammates: { id: @teammate.id, organization: organization })
                  .includes(:huddle)
                  .load

    # Load page visits for this person
    @most_visited_pages = @teammate.person.page_visits.most_visited.limit(5)
    @most_recent_pages = @teammate.person.page_visits.recent.limit(5)
  end

  def complete_picture
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    # Complete picture view - detailed view for managers to see teammate's position, assignments, and milestones
    # Filter by the organization from the route
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :position, :manager)
                                 &.where(company: organization)
                                 &.order(started_at: :desc)
                                 &.decorate || []
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = organization

    # Filter assignments to only show those for this organization
    @assignment_tenures = @teammate&.assignment_tenures&.active
                                &.joins(:assignment)
                                &.where(assignments: { company: organization })
                                &.includes(:assignment) || []
    
    # Filter milestones to only show those for abilities in this organization
    @teammate_milestones = @teammate&.teammate_milestones
                                &.joins(:ability)
                                &.where(abilities: { organization: organization })
                                &.includes(:ability) || []
  end

  def internal
    authorize @teammate, :internal?, policy_class: CompanyTeammatePolicy
    # Internal view - organization-specific data for active employees
    @current_organization = organization
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :manager, position: :position_type)
                                 &.where(company: organization)
                                 &.order(started_at: :desc)
                                 &.decorate || []
    @teammates = @teammate.person.teammates.includes(:organization)

    # Active employment tenure details
    @active_employment_tenure = @employment_tenures.find { |t| t.company == organization && t.ended_at.nil? }
    
    # Earliest start date of employment tenure
    @earliest_start_date = if @teammate.first_employed_at.present?
      @teammate.first_employed_at
    elsif @employment_tenures.any?
      @employment_tenures.map(&:started_at).compact.min
    else
      nil
    end

    # Active departments/teams within this company
    company_descendant_ids = organization.self_and_descendants.map(&:id)
    @active_departments_and_teams = @teammate.person.teammates
      .joins(:organization)
      .where(organizations: { id: company_descendant_ids, type: ['Department', 'Team'] })
      .where(last_terminated_at: nil)
      .includes(:organization)
      .order('organizations.name')

    # Recent observations where teammate is observee (company or fully public)
    @observations_as_observee = Observation
      .where(id: @teammate.observees.select(:observation_id))
      .where(company: organization)
      .where(privacy_level: ['public_to_company', 'public_to_world'])
      .where.not(published_at: nil)
      .where("deleted_at IS NULL")
      .includes(:observer, :company)
      .order(observed_at: :desc)
      .limit(10)

    # Recent observations where teammate is observer (company or fully public)
    @observations_as_observer = @teammate.person.observations
      .where(company: organization)
      .where(privacy_level: ['public_to_company', 'public_to_world'])
      .where.not(published_at: nil)
      .where("deleted_at IS NULL")
      .includes(:company)
      .order(observed_at: :desc)
      .limit(10)

    # Publicly visible active goals where teammate is the owner, with last check-in
    @public_goals = Goal
      .where(company: organization)
      .where(privacy_level: 'everyone_in_company')
      .where(owner_type: 'Teammate', owner_id: @teammate.id)
      .active
      .includes(:goal_check_ins, :creator, :owner)
      .order(created_at: :desc)
      .limit(20)
    
    # Load last check-in for each goal
    @public_goals.each do |goal|
      goal.instance_variable_set(:@last_check_in, goal.goal_check_ins.recent.first)
    end

    # Debug mode - gather comprehensive authorization data
    if params[:debug] == 'true'
      gather_debug_data
    end
  end

  def update_permission
    authorize @teammate, :update_permission?, policy_class: CompanyTeammatePolicy
    
    permission_type = params[:permission_type]
    permission_value = params[:permission_value]
    org = organization
    
    # Update the teammate record (already found via set_teammate)
    access = @teammate
    
    # Update the specific permission
    case permission_type
    when 'can_manage_employment'
      access.can_manage_employment = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    when 'can_create_employment'
      access.can_create_employment = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    when 'can_manage_maap'
      access.can_manage_maap = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    when 'can_manage_prompts'
      access.can_manage_prompts = permission_value == 'true' ? true : (permission_value == 'false' ? false : nil)
    else
      redirect_to organization_company_teammate_path(org, @teammate), alert: 'Invalid permission type.'
      return
    end

    # Debug logging
    Rails.logger.info("Updating permission: teammate_id=#{@teammate.id}, org_id=#{org.id}, permission_type=#{permission_type}, permission_value=#{permission_value}, type=#{access.type}")
    Rails.logger.info("Teammate attributes before save: #{access.attributes.inspect}")
    
    # Save the access record
    if access.save
      Rails.logger.info("Successfully saved teammate permission: #{access.id}")
      redirect_to organization_company_teammate_path(org, @teammate), notice: 'Permission updated successfully.'
    else
      error_message = "Failed to update permission: #{access.errors.full_messages.join(', ')}"
      Rails.logger.error("Failed to save teammate permission: #{error_message}")
      Rails.logger.error("Teammate errors: #{access.errors.inspect}")
      Rails.logger.error("Teammate attributes: #{access.attributes.inspect}")
      redirect_to organization_company_teammate_path(org, @teammate), alert: error_message
    end
  end

  def assignment_selection
    authorize @teammate, :manage_assignments?, policy_class: CompanyTeammatePolicy
    
    @assignments = organization.assignments.includes(:position_assignments).ordered
    @current_employment = @teammate&.employment_tenures&.active&.first
    
    # Get required assignment IDs from position
    @required_assignment_ids = if @current_employment&.position
      @current_employment.position.assignments.pluck(:id)
    else
      []
    end
    
    # Get already assigned assignment IDs (active tenures)
    @assigned_assignment_ids = @teammate.assignment_tenures.active.pluck(:assignment_id)
  end

  def update_assignments
    authorize @teammate, :manage_assignments?, policy_class: CompanyTeammatePolicy
    
    assignment_ids = params[:assignment_ids] || []
    assignment_ids = assignment_ids.map(&:to_i).compact
    
    # Get currently active assignment IDs
    current_assignment_ids = @teammate.assignment_tenures.active.pluck(:assignment_id)
    
    # Find new assignments to add
    new_assignment_ids = assignment_ids - current_assignment_ids
    
    # Create tenures for new assignments
    new_assignment_ids.each do |assignment_id|
      assignment = Assignment.find_by(id: assignment_id, company: organization)
      next unless assignment
      
      # Only create if no active tenure exists
      unless @teammate.assignment_tenures.active.exists?(assignment_id: assignment_id)
        @teammate.assignment_tenures.create!(
          assignment: assignment,
          started_at: Date.current,
          anticipated_energy_percentage: 0
        )
      end
    end
    
    redirect_to organization_company_teammate_check_ins_path(organization, @teammate), notice: 'Assignments updated successfully.'
  end

  def update
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    if @teammate.person.update(person_params)
      redirect_to organization_company_teammate_path(organization, @teammate), notice: 'Profile updated successfully!'
    else
      capture_error_in_sentry(ActiveRecord::RecordInvalid.new(@teammate.person), {
        method: 'update_profile',
        teammate_id: @teammate.id,
        validation_errors: @teammate.person.errors.full_messages
      })
      setup_show_instance_variables
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Handle unique constraint violations (like duplicate phone numbers)
    capture_error_in_sentry(e, {
      method: 'update_profile',
      teammate_id: @teammate&.id,
      error_type: 'unique_constraint_violation'
    })
    @teammate.person.errors.add(:unique_textable_phone_number, 'is already taken by another user')
    setup_show_instance_variables
    render :show, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    # Handle other database constraint violations
    capture_error_in_sentry(e, {
      method: 'update_profile',
      teammate_id: @teammate&.id,
      error_type: 'database_constraint_violation'
    })
    @teammate.person.errors.add(:base, 'Unable to update profile due to a database constraint. Please try again.')
    setup_show_instance_variables
    render :show, status: :unprocessable_entity
  rescue => e
    capture_error_in_sentry(e, {
      method: 'update_profile',
      teammate_id: @teammate&.id
    })
    @teammate.person.errors.add(:base, 'An unexpected error occurred while updating your profile. Please try again.')
    setup_show_instance_variables
    render :show, status: :unprocessable_entity
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:id])
  end

  def maap_snapshot
    @maap_snapshot ||= MaapSnapshot.find(params[:maap_snapshot_id])
  end

  def load_current_maap_data
    # Load current MAAP data for comparison
    @current_employment = @teammate&.employment_tenures&.active&.first
    @current_assignments = @teammate&.assignment_tenures&.active&.includes(:assignment) || []
    @current_milestones = @teammate&.teammate_milestones&.includes(:ability) || []
    @current_maap_data = {
      assignments: @teammate&.assignment_tenures&.active&.includes(:assignment) || [],
      check_ins: AssignmentCheckIn.joins(:teammate).where(teammate: @teammate, assignments: { company: organization }).includes(:assignment),
      milestones: @teammate&.teammate_milestones&.includes(:ability) || [],
      aspirations: organization.aspirations.includes(:ability) # Aspirations belong to organization, not teammate
    }
  end

  def load_assignments_and_check_ins
    # Load assignments where the teammate has ever had a tenure, filtered by organization
    return unless @teammate
    
    assignment_ids = @teammate.assignment_tenures.distinct.pluck(:assignment_id)
    assignments = Assignment.where(id: assignment_ids, company: organization).includes(:assignment_tenures)
    
    @assignment_data = assignments.map do |assignment|
      active_tenure = @teammate.assignment_tenures.where(assignment: assignment).active.first
      most_recent_tenure = @teammate.assignment_tenures.where(assignment: assignment).order(:started_at).last
      
      open_check_in = AssignmentCheckIn.where(teammate: @teammate, assignment: assignment).open.first
      
      {
        assignment: assignment,
        active_tenure: active_tenure,
        most_recent_tenure: most_recent_tenure,
        open_check_in: open_check_in
      }
    end.sort_by { |data| -(data[:active_tenure]&.anticipated_energy_percentage || 0) }
    
    # Load assignments and check-ins for the organization
    @assignments = @teammate.assignment_tenures.active
                         .joins(:assignment)
                         .where(assignments: { company: organization })
                         .includes(:assignment)
    
    @check_ins = AssignmentCheckIn.joins(:assignment)
                                  .where(teammate: @teammate, assignments: { company: organization })
                                  .includes(:assignment)
  end

  def execute_maap_changes!
    service = MaapChangeExecutionService.new(
      maap_snapshot: maap_snapshot,
      current_user: current_company_teammate
    )
    service.execute!
  end

  # Helper methods for execute_changes view
  helper_method :can_see_manager_private_data?, :can_see_employee_private_data?, :format_private_field_value, :employment_has_changes?, :assignment_has_changes?, :milestone_has_changes?, :check_in_has_changes?, :can_see_manager_private_notes?, :teammate
  
  def assignment_has_changes?(assignment)
    change_detection_service.assignment_has_changes?(assignment)
  end

  def change_detection_service
    @change_detection_service ||= MaapChangeDetectionService.new(person: @teammate.person, maap_snapshot: @maap_snapshot, current_user: current_company_teammate)
  end

  def can_see_manager_private_data?(employee_teammate)
    # Only allow managers of other teammates to see manager private data
    # Exclude the case where current_person == employee (employees can't see their own manager data)
    return false if current_person == employee_teammate.person
    
    policy(employee_teammate).manager?
  end

  def can_see_employee_private_data?(employee_teammate)
    current_person == employee_teammate.person
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
    current_check_in = AssignmentCheckIn.where(teammate: @teammate, assignment: assignment).open.first
    
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
    # Only managers and the teammate themselves can see manager private notes
    current_person == @teammate.person || authorize(@teammate, :manager?, policy_class: CompanyTeammatePolicy)
  rescue Pundit::NotAuthorizedError
    false
  end

  def teammate
    @teammate
  end

  def gather_debug_data
    @debug_mode = true
    
    debug_service = Debug::AuthorizationDebugService.new(
      current_user: current_person,
      subject_person: @teammate.person,
      organization: organization,
      session: session
    )
    
    @debug_data = debug_service.gather_all_data
  end

  def setup_show_instance_variables
    # Get all employment tenures for this organization
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :position, :manager)
                                 &.where(company: organization)
                                 &.order(started_at: :desc)
                                 &.decorate || []
    # Get all assignment tenures for this organization
    @assignment_tenures = @teammate&.assignment_tenures&.includes(:assignment)
                                 &.joins(:assignment)
                                 &.where(assignments: { company: organization })
                                 &.order(started_at: :desc) || []
    @teammates = @teammate.person.teammates.includes(:organization)
    
    # Preload huddle associations to avoid N+1 queries
    HuddleParticipant.joins(:teammate)
                    .where(teammates: { id: @teammate.id, organization: organization })
                    .includes(:huddle, huddle: :huddle_playbook)
                    .load
    HuddleFeedback.joins(:teammate)
                  .where(teammates: { id: @teammate.id, organization: organization })
                  .includes(:huddle)
                  .load
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :middle_name, :suffix, 
                                  :unique_textable_phone_number, :timezone,
                                  :preferred_name, :gender_identity, :pronouns)
  end

end


