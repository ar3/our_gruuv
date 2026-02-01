class Organizations::CompanyTeammatesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    # Organization-scoped teammate view - filtered by the organization from the route
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :position, :manager_teammate)
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
                    .includes(:huddle, huddle: :team)
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
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :position, :manager_teammate)
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

  def about_me
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    
    # Check if onboarding spotlight should be shown
    # Only show on viewing teammate's own page and when they don't have BOTH an observation AND a goal
    # Also check company preference to see if onboarding encouragement is enabled
    viewing_own_page = current_person == @teammate.person
    @has_observations = current_person ? Observation.by_observer(current_person).exists? : false
    @has_goals = Goal.where(creator: @teammate).or(Goal.where(owner_type: 'CompanyTeammate', owner_id: @teammate.id)).exists?
    
    # Check company preference - default to 'true' if not set (backward compatibility)
    company_preference = company.company_label_preferences.find_by(label_key: 'encourage_goal_and_observation')
    encouragement_enabled = company_preference.nil? || company_preference.label_value == 'true'
    
    @show_onboarding_spotlight = viewing_own_page && !(@has_observations && @has_goals) && encouragement_enabled
    
    # Load data for sections moved from check-ins
    load_goals_for_about_me
    load_stories_for_about_me
    load_prompts_for_about_me
    load_one_on_one_for_about_me
    
    # Load data for read-only check-in sections
    load_position_check_in_data
    load_assignment_check_in_data
    load_aspiration_check_in_data
    load_abilities_data
    load_viewer_check_in_readiness_for_about_me
  end

  def internal
    authorize @teammate, :internal?, policy_class: CompanyTeammatePolicy
    # Internal view - organization-specific data for teammates (active, inactive, or not yet active)
    @current_organization = organization
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :manager_teammate, position: :title)
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

    # Active assignment tenures for this teammate in this organization
    # Sort by energy (highest first), then alphabetically by assignment title
    @active_assignment_tenures = @teammate&.assignment_tenures&.active
                                      &.joins(:assignment)
                                      &.where(assignments: { company: organization })
                                      &.includes(:assignment)
                                      &.order(Arel.sql('COALESCE(assignment_tenures.anticipated_energy_percentage, 0) DESC, assignments.title ASC')) || []

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
      .where(owner_type: 'CompanyTeammate', owner_id: @teammate.id)
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

  def permissions
    skip_authorization
    
    @return_url = organization_company_teammate_path(organization, @teammate)
    @return_text = "Back to Profile"
    
    # Check if user can modify permissions (will be used in the view)
    @can_modify = policy(@teammate).update_permission? if @teammate
    
    # Find who has each permission in this organization
    @who_has_employment_management = organization.teammates.with_employment_management.includes(:person)
    @who_has_employment_creation = organization.teammates.with_employment_creation.includes(:person)
    @who_has_maap_management = organization.teammates.with_maap_management.includes(:person)
    @who_has_prompts_management = organization.teammates.with_prompts_management.includes(:person)
    @who_has_departments_and_teams_management = organization.teammates.with_departments_and_teams_management.includes(:person)
    @who_has_customize_company = organization.teammates.with_customize_company.includes(:person)
    
    render layout: 'overlay'
  end

  def update_permissions
    skip_authorization
    
    # Check authorization but don't raise error - let the view handle it
    unless policy(@teammate).update_permission?
      redirect_to permissions_organization_company_teammate_path(organization, @teammate), alert: 'You do not have permission to update permissions.'
      return
    end
    
    org = organization
    access = @teammate
    
    # Update all permissions from params
    # Rails checkboxes with "true"/"false" values send "true" when checked, "false" when unchecked
    # If param is missing (shouldn't happen with our form), keep current value
    access.can_manage_employment = if params[:can_manage_employment].present?
      params[:can_manage_employment] == 'true'
    else
      access.can_manage_employment
    end
    
    access.can_create_employment = if params[:can_create_employment].present?
      params[:can_create_employment] == 'true'
    else
      access.can_create_employment
    end
    
    access.can_manage_maap = if params[:can_manage_maap].present?
      params[:can_manage_maap] == 'true'
    else
      access.can_manage_maap
    end
    
    access.can_manage_prompts = if params[:can_manage_prompts].present?
      params[:can_manage_prompts] == 'true'
    else
      access.can_manage_prompts
    end
    
    access.can_manage_departments_and_teams = if params[:can_manage_departments_and_teams].present?
      params[:can_manage_departments_and_teams] == 'true'
    else
      access.can_manage_departments_and_teams
    end
    
    access.can_customize_company = if params[:can_customize_company].present?
      params[:can_customize_company] == 'true'
    else
      access.can_customize_company
    end
    
    # Save the access record
    if access.save
      redirect_to organization_company_teammate_path(org, @teammate), notice: 'Permissions updated successfully.'
    else
      error_message = "Failed to update permissions: #{access.errors.full_messages.join(', ')}"
      Rails.logger.error("Failed to save teammate permissions: #{error_message}")
      Rails.logger.error("Teammate errors: #{access.errors.inspect}")
      Rails.logger.error("Teammate attributes: #{access.attributes.inspect}")
      Rails.logger.error("Params received: #{params.inspect}")
      redirect_to permissions_organization_company_teammate_path(org, @teammate), alert: error_message
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

  def assignment_tenure_check_in_bypass
    # Check if user is a manager of this teammate OR has manage_employment permission
    # Use in_managerial_hierarchy_of? directly to check for actual manager relationship
    # (not manager? which is too permissive - allows any teammate in same organization)
    is_manager = current_company_teammate&.in_managerial_hierarchy_of?(@teammate) || false
    has_manage_employment = policy(organization).manage_employment?
    
    # Authorize: manager or has manage_employment permission
    # If viewing yourself, only allow if you have manage_employment permission (admin/HR role)
    # Otherwise, allow if you're a manager of this teammate OR have manage_employment permission
    viewing_self = current_company_teammate == @teammate
    
    if viewing_self
      # When viewing yourself, require manage_employment permission (admin/HR can bypass their own check-ins)
      unless has_manage_employment
        skip_authorization
        raise Pundit::NotAuthorizedError
      end
    else
      # When viewing someone else, require either manager relationship OR manage_employment permission
      unless is_manager || has_manage_employment
        skip_authorization
        raise Pundit::NotAuthorizedError
      end
    end
    
    # User has permission - perform authorization for Pundit verification
    # Use manager? for manager relationships, or skip if they have manage_employment (which is checked above)
    if has_manage_employment
      skip_authorization
    else
      authorize @teammate, :manager?, policy_class: CompanyTeammatePolicy
    end
    
    @current_organization = organization
    
    # Load all assignments for the organization
    company = organization.root_company || organization
    @assignments = Assignment.where(company: company.self_and_descendants)
                            .includes(:department, :company)
                            .ordered
    
    # For each assignment, load tenure data
    @assignment_data = {}
    @assignments.each do |assignment|
      # Get the latest tenure (most recent by started_at)
      latest_tenure = @teammate.assignment_tenures
                                .where(assignment: assignment)
                                .order(started_at: :desc)
                                .first
      
      @assignment_data[assignment.id] = {
        assignment: assignment,
        latest_tenure: latest_tenure
      }
    end
    
    # Sort all assignments by full name (company > department hierarchy > assignment name)
    # Use the helper method's logic to ensure consistent sorting with display
    @assignments = @assignments.sort_by do |assignment|
      path = []
      
      # Start with company
      company = assignment.company
      path << company.name if company
      
      # Add department hierarchy if present (excluding the company which is already included)
      if assignment.department
        current = assignment.department
        dept_path = []
        while current
          # Stop before including the company (which is already in the path)
          break if current.company?
          dept_path.unshift(current.name)
          current = current.parent
        end
        path.concat(dept_path)
      end
      
      # Add assignment title
      path << assignment.title
      
      path.join(' > ')
    end
  end

  def update_assignment_tenure_check_in_bypass
    # Check if user is a manager of this teammate OR has manage_employment permission
    # Use in_managerial_hierarchy_of? directly to check for actual manager relationship
    # (not manager? which is too permissive - allows any teammate in same organization)
    is_manager = current_company_teammate&.in_managerial_hierarchy_of?(@teammate) || false
    has_manage_employment = policy(organization).manage_employment?
    
    # Authorize: manager or has manage_employment permission
    # If viewing yourself, only allow if you have manage_employment permission (admin/HR role)
    # Otherwise, allow if you're a manager of this teammate OR have manage_employment permission
    viewing_self = current_company_teammate == @teammate
    
    if viewing_self
      # When viewing yourself, require manage_employment permission (admin/HR can bypass their own check-ins)
      unless has_manage_employment
        skip_authorization
        raise Pundit::NotAuthorizedError
      end
    else
      # When viewing someone else, require either manager relationship OR manage_employment permission
      unless is_manager || has_manage_employment
        skip_authorization
        raise Pundit::NotAuthorizedError
      end
    end
    
    # User has permission - perform authorization for Pundit verification
    # Use manager? for manager relationships, or skip if they have manage_employment (which is checked above)
    if has_manage_employment
      skip_authorization
    else
      authorize @teammate, :manager?, policy_class: CompanyTeammatePolicy
    end
    
    assignment_tenures_params = params[:assignment_tenures] || {}
    changes_made = false
    
    ActiveRecord::Base.transaction do
      assignment_tenures_params.each do |assignment_id_str, energy_percentage_str|
        assignment_id = assignment_id_str.to_i
        energy_percentage = energy_percentage_str.to_i
        
        company = organization.root_company || organization
        company_ids = company.self_and_descendants.map(&:id)
        assignment = Assignment.where(id: assignment_id, company_id: company_ids).first
        next unless assignment
        
        active_tenure = @teammate.assignment_tenures.where(assignment: assignment).active.first
        
        if active_tenure
          if energy_percentage == 0
            # End the tenure
            active_tenure.update!(
              ended_at: Date.current,
              anticipated_energy_percentage: 0
            )
            changes_made = true
          else
            current_energy = active_tenure.anticipated_energy_percentage
            if current_energy != energy_percentage
              # Update the energy percentage
              active_tenure.update!(anticipated_energy_percentage: energy_percentage)
              changes_made = true
            end
          end
        elsif energy_percentage > 0
          # Create new tenure
          @teammate.assignment_tenures.create!(
            assignment: assignment,
            started_at: Date.current,
            anticipated_energy_percentage: energy_percentage
          )
          changes_made = true
        end
      end
      
      # Create MAAP snapshot if changes were made
      if changes_made
        unless current_company_teammate
          raise "current_company_teammate is required to create MAAP snapshot"
        end
        
        request_info = build_request_info
        snapshot = MaapSnapshot.build_for_employee(
          employee_teammate: @teammate,
          creator_teammate: current_company_teammate,
          change_type: 'assignment_management',
          reason: 'Check-in Bypass',
          request_info: request_info
        )
        snapshot.effective_date = Date.current
        snapshot.save!
      end
    end
    
    if changes_made
      redirect_to complete_picture_organization_company_teammate_path(organization, @teammate),
                  notice: 'Assignment tenures updated successfully.'
    else
      redirect_to assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, @teammate),
                  alert: 'No changes were made.'
    end
  rescue Pundit::NotAuthorizedError
    # Re-raise authorization errors so they're handled by ApplicationController's rescue_from
    raise
  rescue => e
    Rails.logger.error("Error updating assignment tenures: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    redirect_to assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, @teammate),
                alert: "Error updating assignment tenures: #{e.message}"
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
    current.manager_teammate_id.to_s != proposed['manager_teammate_id'].to_s ||
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
        current_check_in.manager_completed_by_teammate_id.to_s != proposed_data['manager_check_in']['manager_completed_by_teammate_id'].to_s
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
        current_check_in.finalized_by_teammate_id.to_s != proposed_data['official_check_in']['finalized_by_teammate_id'].to_s
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
    @employment_tenures = @teammate&.employment_tenures&.includes(:company, :position, :manager_teammate)
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
                    .includes(:huddle, huddle: :team)
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

  # Data loading methods for about_me page
  def load_goals_for_about_me
    if @teammate
      # Get ALL active goals (not filtered by timeframe scopes)
      # This ensures status indicator and view use the same query
      base_goals = Goal.for_teammate(@teammate).active.includes(:goal_check_ins)
      all_active_goals = base_goals.to_a
      
      # Categorize goals by timeframe using instance method (includes goals without target dates)
      @now_goals = []
      @next_goals = []
      @later_goals = []
      
      all_active_goals.each do |goal|
        case goal.timeframe
        when :now
          @now_goals << goal
        when :next
          @next_goals << goal
        when :later
          @later_goals << goal
        else
          # Goals without target dates or with past dates go into :later for display
          @later_goals << goal
        end
      end
      
      goal_ids = all_active_goals.map(&:id)
      current_week_start = Date.current.beginning_of_week(:monday)
      
      all_check_ins = GoalCheckIn
        .where(goal_id: goal_ids)
        .includes(:confidence_reporter)
        .order(check_in_week_start: :desc)
      
      latest_check_ins = {}
      all_check_ins.each do |check_in|
        latest_check_ins[check_in.goal_id] ||= check_in
      end
      
      current_week_check_ins = GoalCheckIn
        .where(goal_id: goal_ids, check_in_week_start: current_week_start)
        .index_by(&:goal_id)
      
      all_active_goals.each do |goal|
        goal.instance_variable_set(:@latest_check_in, latest_check_ins[goal.id])
        goal.instance_variable_set(:@needs_check_in, current_week_check_ins[goal.id].nil?)
      end
      
      # Check if any goals were completed in the last 90 days (for status indicator)
      @goals_completed_recently = base_goals.where('completed_at >= ?', 90.days.ago).exists?
      
      # Calculate goals with check-ins in the past two weeks
      cutoff_week = (Date.current - 14.days).beginning_of_week(:monday)
      recent_check_in_goal_ids = all_check_ins
        .select { |check_in| check_in.check_in_week_start >= cutoff_week }
        .map(&:goal_id)
        .uniq
      @goals_with_recent_check_ins_count = all_active_goals.count { |goal| recent_check_in_goal_ids.include?(goal.id) }
      
      # Calculate goals completed in the last 90 days
      @goals_completed_count = Goal.for_teammate(@teammate)
        .where('completed_at >= ?', 90.days.ago)
        .where(deleted_at: nil)
        .count
      
      # Calculate draft goals count
      @draft_goals_count = Goal.for_teammate(@teammate)
        .draft
        .where(deleted_at: nil)
        .count
      
      @goals_check_in_url = organization_goals_path(
        organization,
        owner_type: 'CompanyTeammate',
        owner_id: @teammate.id,
        view: 'check-in'
      )
    else
      @now_goals = []
      @next_goals = []
      @later_goals = []
      @goals_with_recent_check_ins_count = 0
      @goals_completed_count = 0
      @draft_goals_count = 0
      @goals_check_in_url = organization_goals_path(organization)
    end
  end

  def load_stories_for_about_me
    if @teammate
      # Use same ObservationsQuery as filtered_observations so collapsed counts and expanded lists match "View All"
      since_date = 30.days.ago
      timeframe_start = since_date.to_date.to_s
      timeframe_end = Time.current.to_date.to_s
      teammate_ids = @teammate.person.teammates.where(organization: organization).pluck(:id)

      # Observations given: observer = teammate, published, not journal, last 30 days, exclude self-observations
      given_params = {
        observer_id: @teammate.person.id,
        exclude_observer_as_observee: true,
        timeframe: 'between',
        timeframe_start_date: timeframe_start,
        timeframe_end_date: timeframe_end
      }
      given_query = ObservationsQuery.new(organization, given_params, current_person: current_person)
      given_observations = given_query.call
      @observations_given_count = given_observations.count
      @recent_observations_given = given_observations.limit(3).includes(:observer, { observed_teammates: :person }, :observation_ratings)

      # Observations received: teammate is observee, published, not journal, last 30 days
      received_params = {
        observee_ids: teammate_ids,
        timeframe: 'between',
        timeframe_start_date: timeframe_start,
        timeframe_end_date: timeframe_end
      }
      received_query = ObservationsQuery.new(organization, received_params, current_person: current_person)
      received_observations = received_query.call
      @observations_received_count = received_observations.count
      @recent_observations_received = received_observations.limit(3).includes(:observer, { observed_teammates: :person }, :observation_ratings)
      
      # Build filter URLs (same params as ObservationsQuery so "View All" shows the same set)
      casual_name = @teammate.person.casual_name
      @observations_given_url = filtered_observations_organization_observations_path(
        organization,
        observer_id: @teammate.person.id,
        start_date: since_date.iso8601,
        return_url: about_me_organization_company_teammate_path(organization, @teammate),
        return_text: "Back to About #{casual_name}"
      )
      
      @observations_received_url = filtered_observations_organization_observations_path(
        organization,
        observee_ids: teammate_ids,
        start_date: since_date.iso8601,
        return_url: about_me_organization_company_teammate_path(organization, @teammate),
        return_text: "Back to About #{casual_name}"
      )
      
      # Draft observations (where teammate is observer)
      draft_observations = Observation
        .where(observer_id: @teammate.person.id, company: organization)
        .where(published_at: nil)
        .where(deleted_at: nil)
      
      @draft_observation_count = draft_observations.count
      @draft_observations_url = organization_observations_path(
        organization,
        observer_id: @teammate.person.id,
        draft: true,
        return_url: about_me_organization_company_teammate_path(organization, @teammate),
        return_text: "Back to About #{casual_name}"
      )
      @observations_involving_url = organization_observations_path(
        organization,
        involving_teammate_id: @teammate.id,
        return_url: about_me_organization_company_teammate_path(organization, @teammate),
        return_text: "Back to About #{casual_name}"
      )
    else
      @observations_given_count = 0
      @recent_observations_given = []
      @observations_received_count = 0
      @recent_observations_received = []
      @observations_given_url = organization_observations_path(organization)
      @observations_received_url = organization_observations_path(organization)
      @draft_observation_count = 0
      @draft_observations_url = organization_observations_path(organization)
      @observations_involving_url = organization_observations_path(organization)
    end
  end

  def load_prompts_for_about_me
    if @teammate
      company = organization.root_company || organization
      
      company_teammate = if @teammate.is_a?(CompanyTeammate) && @teammate.organization == company
        @teammate
      else
        CompanyTeammate.find_by(organization: company, person: @teammate.person)
      end
      
      if company_teammate && current_company_teammate
        pundit_user = OpenStruct.new(user: current_company_teammate, impersonating_teammate: nil)
        policy = PromptPolicy::Scope.new(pundit_user, Prompt)
        accessible_prompts = policy.resolve
        
        prompts_for_teammate = accessible_prompts.where(company_teammate: company_teammate)
        
        # Get open prompts only for the expanded view
        @open_prompts = prompts_for_teammate
          .open
          .includes(:prompt_template, :prompt_answers, prompt_goals: :goal)
          .order(created_at: :desc)
        
        # Get all prompts for statistics
        all_prompts = prompts_for_teammate.includes(:prompt_template, :prompt_answers, prompt_goals: :goal)
        
        # Calculate statistics for summary
        active_templates = PromptTemplate.where(company: company).available
        @prompts_available_count = active_templates.count
        
        # Count reflections started (all prompts)
        @reflections_started_count = all_prompts.count
        
        # Count questions answered (non-empty text)
        @questions_answered_count = PromptAnswer
          .where(prompt: all_prompts)
          .where("text IS NOT NULL AND text != ''")
          .count
        
        # Count total questions across all active templates
        @total_questions_count = PromptQuestion
          .where(prompt_template: active_templates)
          .active
          .count
        
        # Count total goals associated with prompts
        @total_goals_count = PromptGoal
          .where(prompt: all_prompts)
          .count
        
        # Count reflections with goals
        @reflections_with_goals_count = all_prompts
          .joins(:prompt_goals)
          .distinct
          .count
        
        @prompts_url = organization_prompts_path(organization, teammate: company_teammate.id)
      else
        @open_prompts = []
        @prompts_available_count = 0
        @reflections_started_count = 0
        @questions_answered_count = 0
        @total_questions_count = 0
        @total_goals_count = 0
        @reflections_with_goals_count = 0
        @prompts_url = organization_prompts_path(organization)
      end
    else
      @open_prompts = []
      @prompts_available_count = 0
      @reflections_started_count = 0
      @questions_answered_count = 0
      @total_questions_count = 0
      @total_goals_count = 0
      @reflections_with_goals_count = 0
      @prompts_url = organization_prompts_path(organization)
    end
  end

  def load_one_on_one_for_about_me
    if @teammate
      @one_on_one_link = @teammate.one_on_one_link
      casual_name = @teammate.person.casual_name
      @one_on_one_url = organization_company_teammate_one_on_one_link_path(
        organization, 
        @teammate,
        return_url: about_me_organization_company_teammate_path(organization, @teammate),
        return_text: "Back to About #{casual_name}"
      )
      
    else
      @one_on_one_link = nil
      casual_name = @teammate&.person&.casual_name || 'Teammate'
      @one_on_one_url = organization_company_teammate_one_on_one_link_path(
        organization, 
        @teammate,
        return_url: about_me_organization_company_teammate_path(organization, @teammate),
        return_text: "Back to About #{casual_name}"
      )
      @asana_sections = []
      @asana_section_tasks = {}
    end
  end

  def load_position_check_in_data
    @position_check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    @latest_finalized_position_check_in = PositionCheckIn.latest_finalized_for(@teammate)
    
    # Get current position from active employment tenure
    active_tenure = @teammate.active_employment_tenure
    @current_position = active_tenure&.position
    @position_display_name = @current_position&.display_name || "not an employee yet"
    @last_check_in_date = if @latest_finalized_position_check_in
      @latest_finalized_position_check_in.official_check_in_completed_at
    else
      nil
    end
  end

  def load_assignment_check_in_data
    # Use the shared helper method to ensure consistency across:
    # - The collapsed alert sentence
    # - The status indicator color  
    # - The expanded assignment list
    active_tenure = @teammate.active_employment_tenure
    @position_display_name_for_assignments = active_tenure&.position&.display_name || "undefined position"
    
    # Get the relevant assignments using the shared method
    relevant_assignments = helpers.relevant_assignments_for_about_me(@teammate, organization)
    @required_assignments = relevant_assignments.to_a # Used in view for summary sentence
    
    # Build maps for position_assignment and assignment_tenure lookups
    required_position_assignments = if active_tenure&.position
      active_tenure.position.required_assignments.includes(:assignment)
    else
      []
    end
    
    active_assignment_tenures = @teammate.assignment_tenures
      .active_and_given_energy
      .includes(:assignment)
      .where(assignments: { company: @teammate.organization })
    
    required_assignments_map = {}
    required_position_assignments.each do |position_assignment|
      required_assignments_map[position_assignment.assignment_id] = position_assignment
    end
    
    active_tenures_map = {}
    active_assignment_tenures.each do |assignment_tenure|
      active_tenures_map[assignment_tenure.assignment_id] = assignment_tenure
    end
    
    cutoff_date = 90.days.ago
    @assignment_check_ins_data = relevant_assignments.map do |assignment|
      check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
      latest_finalized = AssignmentCheckIn
        .where(teammate: @teammate, assignment: assignment)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      {
        assignment: assignment,
        position_assignment: required_assignments_map[assignment.id], # May be nil for active-only assignments
        assignment_tenure: active_tenures_map[assignment.id], # May be nil for required-only assignments
        check_in: check_in,
        latest_finalized: latest_finalized
      }
    end
    
    # Count assignments with finalized check-ins in the last 90 days
    @assignments_with_recent_check_ins_count = @assignment_check_ins_data.count do |data|
      data[:latest_finalized] && data[:latest_finalized].official_check_in_completed_at >= cutoff_date
    end
  end

  def load_aspiration_check_in_data
    # Get all company aspirational values
    @company_aspirations = Aspiration.within_hierarchy(organization).ordered
    @company_name = organization.root_company&.name || organization.name
    
    cutoff_date = 90.days.ago
    @aspiration_check_ins_data = @company_aspirations.map do |aspiration|
      check_in = AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
      latest_finalized = AspirationCheckIn
        .where(teammate: @teammate, aspiration: aspiration)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      {
        aspiration: aspiration,
        check_in: check_in,
        latest_finalized: latest_finalized
      }
    end
    
    # Count aspirational values with finalized check-ins in the last 90 days
    @aspirations_with_recent_check_ins_count = @aspiration_check_ins_data.count do |data|
      data[:latest_finalized] && data[:latest_finalized].official_check_in_completed_at >= cutoff_date
    end
  end

  # Sets instance variables for the "viewer completed their side" sentence on collapsed check-in sections.
  # Only relevant when viewing your own about me page (viewing teammate == about-me teammate).
  def load_viewer_check_in_readiness_for_about_me
    @viewing_own_about_me = current_company_teammate.present? && current_company_teammate == @teammate

    if @viewing_own_about_me
      # Viewer is the employee; count check-ins where they have completed the employee side.
      @viewer_ready_aspiration_count = @aspiration_check_ins_data.count do |data|
        data[:check_in]&.employee_completed_at.present?
      end
      @viewer_ready_assignment_count = @assignment_check_ins_data.count do |data|
        data[:check_in]&.employee_completed_at.present?
      end
      @viewer_ready_position = @position_check_in&.employee_completed_at.present?
    else
      @viewer_ready_aspiration_count = 0
      @viewer_ready_assignment_count = 0
      @viewer_ready_position = false
    end
  end

  def build_request_info
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current.iso8601
    }
  end

  def load_abilities_data
    # Get required assignments and their ability requirements
    active_tenure = @teammate.active_employment_tenure
    
    if active_tenure&.position
      @required_assignments_for_abilities = active_tenure.position.required_assignments.includes(assignment: :assignment_abilities)
      @position_display_name_for_abilities = active_tenure.position.display_name
      
      # Collect all ability milestones
      all_ability_milestones = []
      @abilities_data = @required_assignments_for_abilities.map do |position_assignment|
        assignment = position_assignment.assignment
        assignment_abilities = assignment.assignment_abilities.includes(:ability)
        
        abilities_info = assignment_abilities.map do |assignment_ability|
          ability = assignment_ability.ability
          teammate_milestone = @teammate.teammate_milestones.find_by(ability: ability)
          current_milestone = teammate_milestone&.milestone_level || 0
          required_milestone = assignment_ability.milestone_level
          
          all_ability_milestones << {
            ability: ability,
            required_milestone: required_milestone,
            current_milestone: current_milestone,
            met: current_milestone >= required_milestone
          }
          
          {
            ability: ability,
            required_milestone: required_milestone,
            current_milestone: current_milestone
          }
        end
        
        # Check if all milestones are met
        all_milestones_met = abilities_info.all? do |info|
          info[:current_milestone] >= info[:required_milestone]
        end
        
        {
          assignment: assignment,
          abilities: abilities_info,
          fully_qualified: all_milestones_met
        }
      end
      
      @total_ability_milestones_count = all_ability_milestones.count
      @ability_milestones_met_count = all_ability_milestones.count { |m| m[:met] }
    else
      @required_assignments_for_abilities = []
      @abilities_data = []
      @position_display_name_for_abilities = "undefined position"
      @total_ability_milestones_count = 0
      @ability_milestones_met_count = 0
    end
  end

end


