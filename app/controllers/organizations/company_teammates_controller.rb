class Organizations::CompanyTeammatesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates
  include Organizations::AssignsManagersViewCardForTeammate

  helper MyGrowthExperiencesHelper
  helper MyGrowthAbilitiesHelper
  helper AssignmentEnergyAllocationHelper

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :assign_managers_view_card_for_teammate, only: %i[about_me internal]
  after_action :verify_authorized

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
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
    HuddleParticipant.joins(:company_teammate)
                    .where(teammates: { id: @teammate.id, organization: organization })
                    .includes(:huddle, huddle: :team)
                    .load
    HuddleFeedback.joins(:company_teammate)
                  .where(teammates: { id: @teammate.id, organization: organization })
                  .includes(:huddle)
                  .load

    # Load page visits for this person
    @most_visited_pages = @teammate.person.page_visits.most_visited.limit(5)
    @most_recent_pages = @teammate.person.page_visits.recent.limit(5)
  end

  def complete_picture
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    # Complete picture view - detailed view for managers to see teammate's position, assignments, and milestones
    # Filter by the organization from the route
    @employment_tenures = @teammate&.employment_tenures&.includes(
      :company, :seat,
      manager_teammate: :person,
      position: [
        :position_level,
        { position_abilities: :ability,
          position_assignments: { assignment: { assignment_abilities: :ability } },
          title: [:department, :position_major_level] }
      ]
    )&.where(company: organization)
                                 &.order(started_at: :desc)
                                 &.decorate || []
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = organization

    load_complete_picture_spotlight_and_observations

    # Filter assignments to only show those for this organization
    @assignment_tenures = @teammate&.assignment_tenures&.active
                                &.joins(:assignment)
                                &.where(assignments: { company: organization })
                                &.includes(assignment: { assignment_abilities: :ability }) || []

    assignment_ids = @assignment_tenures.map(&:assignment_id).uniq
    assignment_ability_ids = @assignment_tenures.flat_map do |tenure|
      tenure.assignment.assignment_abilities.map(&:ability_id)
    end.uniq
    @complete_picture_teammate_milestone_level_by_ability_id = if assignment_ability_ids.any?
                                                                  @teammate.teammate_milestones
                                                                    .where(ability_id: assignment_ability_ids)
                                                                    .pluck(:ability_id, :milestone_level)
                                                                    .to_h
                                                                else
                                                                  {}
                                                                end
    @latest_finalized_assignment_check_ins_by_assignment_id = {}
    if assignment_ids.any?
      AssignmentCheckIn
        .where(company_teammate: @teammate, assignment_id: assignment_ids)
        .closed
        .includes(:assignment, manager_completed_by_teammate: :person, finalized_by_teammate: :person)
        .order(official_check_in_completed_at: :desc)
        .each do |check_in|
          @latest_finalized_assignment_check_ins_by_assignment_id[check_in.assignment_id] ||= check_in
        end
    end

    @complete_picture_assignment_goal_counts_by_id = my_growth_assignment_goal_counts_for_teammate(assignment_ids)

    # Filter milestones to only show those for abilities in this organization
    @teammate_milestones = @teammate&.teammate_milestones
                                &.joins(:ability)
                                &.where(abilities: { company_id: organization.id })
                                &.includes(:ability, certifying_teammate: :person)
                                &.order(attained_at: :desc) || []

    load_complete_picture_ability_milestone_cards
    milestone_card_ability_ids = @complete_picture_ability_milestone_cards.map { |c| c[:ability].id }.uniq
    @complete_picture_ability_goal_counts_by_id = my_growth_ability_goal_counts_for_teammate(milestone_card_ability_ids)
  end

  def about_me
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    assign_viewable_teammates_context!(selected_teammate: @teammate)

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

  def kudos_points
    authorize @teammate, :view_kudos_points?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @person = @teammate.person
    @ledger = @teammate.kudos_ledger
    transactions_scope = @teammate.kudos_transactions.recent
    total_count = transactions_scope.count
    @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
    @transactions = transactions_scope.limit(@pagy.items).offset(@pagy.offset)
    @kudos_return_url = params[:return_url].presence
    @kudos_return_text = params[:return_text].presence
  end

  def my_growth_experiences
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @person = @teammate.person
    @current_organization = organization
    load_my_growth_employment_context
    load_my_growth_experiences_rows
  end

  def my_growth_abilities
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @person = @teammate.person
    @current_organization = organization
    load_my_growth_employment_context
    @position = @current_employment&.position
    load_my_growth_ability_rows
    @my_growth_mileage_summary = MyGrowthMileageSummary.build(
      teammate: @teammate,
      organization: organization,
      ability_rows: @my_growth_ability_rows,
      current_position: @position,
      target_position: @teammate.next_goal_position
    )
  end

  def my_growth_goals
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @person = @teammate.person
    @current_organization = organization
    @timeframe = my_growth_parse_timeframe(params[:timeframe])
    range = my_growth_date_range_for(@timeframe)
    chart_range = range || (52.weeks.ago..Time.current)
    @chart_title_period = my_growth_chart_title_period(@timeframe)
    goals_scope = GoalsChartSeries.goals_base_scope(company).where(owner: @teammate)
    @goals_chart_data = GoalsChartSeries.stacked_series(chart_range, goals_scope)
    graph_goal_ids = goals_scope.active.pluck(:id)
    @goals_for_network_graph = graph_goal_ids.any? ? Goal.where(id: graph_goal_ids).includes(:owner, :creator).order(:title) : []
    @goal_links_for_network_graph = graph_goal_ids.any? ? GoalLink.where(parent_id: graph_goal_ids, child_id: graph_goal_ids).includes(:parent, :child) : []
    load_bulk_confidence_check_goals
  end

  def my_growth_position_change
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @person = @teammate.person
    @current_organization = organization
    load_my_growth_employment_context
    load_my_growth_positions_by_department
    @next_goal_position = @teammate.next_goal_position
    if (pos = @current_employment&.position)
      @current_position_eligibility = PositionEligibilityService.new.check_eligibility(@teammate, pos)
    end
    if @next_goal_position
      @next_goal_position_eligibility = PositionEligibilityService.new.check_eligibility(@teammate, @next_goal_position)
    end
  end

  def update_next_goal_position
    authorize @teammate, :complete_picture?, policy_class: CompanyTeammatePolicy
    @teammate.next_goal_position_id = params[:next_goal_position_id].presence
    if @teammate.save
      redirect_back fallback_location: my_growth_position_change_organization_company_teammate_path(organization, @teammate),
                    notice: 'Next goal position updated.'
    else
      redirect_back fallback_location: my_growth_position_change_organization_company_teammate_path(organization, @teammate),
                    alert: @teammate.errors.full_messages.to_sentence.presence || 'Could not update next goal position.'
    end
  end

  def internal
    authorize @teammate, :internal?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate, all_active_in_organization: true)
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

    # Active departments/teams: with STI removed, teammates only belong to Organizations.
    # Show company's departments and teams the person is associated with via assignments/roles, or empty.
    @active_departments_and_teams = []

    # Recent observations where teammate is observee (company or fully public)
    observation_includes = [:observer, :company, observees: { company_teammate: :person }]

    @observations_as_observee = Observation
      .where(id: @teammate.observees.select(:observation_id))
      .where(company: organization)
      .where(privacy_level: ['public_to_company', 'public_to_world'])
      .where.not(published_at: nil)
      .where("deleted_at IS NULL")
      .includes(*observation_includes)
      .order(observed_at: :desc)
      .limit(10)

    # Recent observations where teammate is observer (company or fully public)
    @observations_as_observer = @teammate.person.observations
      .where(company: organization)
      .where(privacy_level: ['public_to_company', 'public_to_world'])
      .where.not(published_at: nil)
      .where("deleted_at IS NULL")
      .includes(*observation_includes)
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

    # URLs for "View all" links on observation sections (observation index with filter)
    casual_name = @teammate.person.casual_name
    internal_return = internal_organization_company_teammate_path(organization, @teammate)
    @observations_about_url = organization_observations_path(
      organization,
      observee_ids: [@teammate.id],
      return_url: internal_return,
      return_text: "Back to #{@teammate.person.display_name}"
    )
    @observations_by_url = organization_observations_path(
      organization,
      observer_id: @teammate.person.id,
      return_url: internal_return,
      return_text: "Back to #{@teammate.person.display_name}"
    )

    # Required assignments (from position) that don't have an active assignment tenure
    # Used for "Set N default assignments" button on internal view
    if @active_employment_tenure&.position
      required_assignments = @active_employment_tenure.position.required_assignments.includes(:assignment).map(&:assignment)
      active_tenure_assignment_ids = @teammate.assignment_tenures
        .active
        .joins(:assignment)
        .where(assignments: { company: organization })
        .pluck(:assignment_id)
      @required_assignments_without_active_tenure = required_assignments.reject { |a| active_tenure_assignment_ids.include?(a.id) }
    else
      @required_assignments_without_active_tenure = []
    end

    # Viewer can set default assignments if in teammate's managerial hierarchy or has manage_employment
    @can_set_default_assignments = (
      current_company_teammate&.in_managerial_hierarchy_of?(@teammate) ||
      policy(organization).manage_employment?
    )

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
    @who_has_kudos_rewards_management = organization.teammates.with_kudos_management.includes(:person)
    
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
    
    access.can_manage_kudos_rewards = if params[:can_manage_kudos_rewards].present?
      params[:can_manage_kudos_rewards] == 'true'
    else
      access.can_manage_kudos_rewards
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

    @current_employment = @teammate&.employment_tenures&.active&.first
    position = @current_employment&.position

    @required_assignment_ids = position ? position.required_assignments.pluck(:assignment_id) : []
    @suggested_assignment_ids = position ? position.suggested_assignments.pluck(:assignment_id) : []
    @assigned_assignment_ids = @teammate.assignment_tenures.active.pluck(:assignment_id)

    @assignments = organization.assignments.unarchived
                                .includes(:department)
                                .to_a
                                .sort_by do |assignment|
                                  dept_sort = assignment.department ? [1, assignment.department.display_name.downcase] : [0, ""]
                                  [dept_sort, assignment.title.downcase]
                                end
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

    EngagementHealth.schedule_refresh_for(@teammate.id) if new_assignment_ids.any?

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

    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @current_organization = organization
    
    # Load all assignments for the organization
    company = organization.root_company || organization
    @assignments = Assignment.unarchived
                            .where(company: company.self_and_descendants)
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
          dept_path.unshift(current.name)
          current = current.parent_department
        end
        path.concat(dept_path)
      end
      
      # Add assignment title
      path << assignment.title
      
      path.join(' > ')
    end

    @assignment_energy_allocation = CheckIns::TenureBypassAssignmentEnergyAllocationSummary.for_tenure_bypass(
      teammate: @teammate,
      assignments: @assignments,
      assignment_data: @assignment_data,
      organization: organization
    )
    @assignment_energy_employee_name = @teammate.person.casual_name
    @assignment_energy_manager_name = current_company_teammate&.person&.casual_name.presence || "Manager"
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
      EngagementHealth.schedule_refresh_for(@teammate.id)
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

  def set_default_assignments
    # Same authorization as assignment_tenure_check_in_bypass: manager or manage_employment
    is_manager = current_company_teammate&.in_managerial_hierarchy_of?(@teammate) || false
    has_manage_employment = policy(organization).manage_employment?
    viewing_self = current_company_teammate == @teammate

    if viewing_self
      unless has_manage_employment
        skip_authorization
        raise Pundit::NotAuthorizedError
      end
    else
      unless is_manager || has_manage_employment
        skip_authorization
        raise Pundit::NotAuthorizedError
      end
    end

    if has_manage_employment
      skip_authorization
    else
      authorize @teammate, :manager?, policy_class: CompanyTeammatePolicy
    end

    active_tenure = @teammate.active_employment_tenure
    position = active_tenure&.position
    unless position
      redirect_to internal_organization_company_teammate_path(organization, @teammate),
                  alert: 'No active position for this teammate.'
      return
    end

    required_assignments = position.required_assignments.includes(:assignment).map(&:assignment)
    active_tenure_assignment_ids = @teammate.assignment_tenures
      .active
      .joins(:assignment)
      .where(assignments: { company: organization })
      .pluck(:assignment_id)
    missing = required_assignments.reject { |a| active_tenure_assignment_ids.include?(a.id) }

    if missing.empty?
      redirect_to internal_organization_company_teammate_path(organization, @teammate),
                  notice: 'All required assignments already have active tenures.'
      return
    end

    ActiveRecord::Base.transaction do
      missing.each do |assignment|
        @teammate.assignment_tenures.create!(
          assignment: assignment,
          started_at: Date.current,
          anticipated_energy_percentage: 5
        )
      end

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

    EngagementHealth.schedule_refresh_for(@teammate.id)

    redirect_to internal_organization_company_teammate_path(organization, @teammate),
                notice: "Created #{missing.size} assignment tenure(s). Recorded as Assignment tenure check-in bypass."
  rescue Pundit::NotAuthorizedError
    raise
  rescue => e
    Rails.logger.error("Error setting default assignments: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    redirect_to internal_organization_company_teammate_path(organization, @teammate),
                alert: "Error setting default assignments: #{e.message}"
  end

  def update
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    if @teammate.person.update(person_params)
      if params[:start_page].present?
        key = "start_page_#{organization.id}"
        UserPreference.for_person(@teammate.person).update_preference(key, params[:start_page])
      end
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

  # Abilities required by current position (direct + required assignments), active assignment tenures,
  # plus any org-scoped earned milestones not covered above (shown without requirement lines).
  def load_complete_picture_ability_milestone_cards
    cards = {}
    earned_by_ability_id = @teammate_milestones.group_by(&:ability_id)

    pos = @current_employment&.position
    if pos
      pos.position_abilities.each do |pa|
        complete_picture_append_ability_requirement!(
          cards,
          ability: pa.ability,
          milestone_level: pa.milestone_level,
          dedupe_key: "position_ability:#{pa.id}",
          label: "Current position"
        )
      end

      pos.required_assignments.each do |pos_assignment|
        assignment = pos_assignment.assignment
        next if assignment.blank? || assignment.company_id != organization.id

        assignment.assignment_abilities.each do |aa|
          complete_picture_append_ability_requirement!(
            cards,
            ability: aa.ability,
            milestone_level: aa.milestone_level,
            dedupe_key: "assignment:#{assignment.id}:#{aa.ability_id}",
            label: assignment.title.to_s
          )
        end
      end
    end

    @assignment_tenures.each do |tenure|
      assignment = tenure.assignment
      next if assignment.blank?

      assignment.assignment_abilities.each do |aa|
        complete_picture_append_ability_requirement!(
          cards,
          ability: aa.ability,
          milestone_level: aa.milestone_level,
          dedupe_key: "assignment:#{assignment.id}:#{aa.ability_id}",
          label: assignment.title.to_s
        )
      end
    end

    earned_by_ability_id.each do |ability_id, milestones|
      next if cards[ability_id]

      ability = milestones.first.ability
      cards[ability_id] = { ability: ability, requirement_keys: [], requirements: [] }
    end

    @complete_picture_ability_milestone_cards = cards.values.sort_by { |c| c[:ability].name.downcase }.map do |slot|
      earned = (earned_by_ability_id[slot[:ability].id] || []).sort_by(&:milestone_level)
      requirements = slot[:requirements].sort_by { |r| [r[:label].to_s.downcase, r[:m]] }
      {
        ability: slot[:ability],
        requirements: requirements,
        earned_milestones: earned,
        earned_by_level: earned.index_by(&:milestone_level)
      }
    end
  end

  def complete_picture_append_ability_requirement!(cards, ability:, milestone_level:, dedupe_key:, label:)
    return if ability.blank? || milestone_level.blank?

    id = ability.id
    slot = cards[id] ||= { ability: ability, requirement_keys: [], requirements: [] }
    return if slot[:requirement_keys].include?(dedupe_key)

    slot[:requirement_keys] << dedupe_key
    slot[:requirements] << { label: label, m: milestone_level.to_i }
  end

  def load_complete_picture_spotlight_and_observations
    @complete_picture_distinct_position_count = @employment_tenures.map(&:position_id).compact.uniq.size

    @complete_picture_earliest_start_date = if @teammate.first_employed_at.present?
      @teammate.first_employed_at.to_date
    elsif @employment_tenures.any?
      @employment_tenures.map(&:started_at).compact.min&.to_date
    end

    @complete_picture_in_position_since_date = @current_employment&.started_at&.to_date

    anchor_at = complete_picture_earliest_official_finalized_at
    @complete_picture_next_check_in_word = helpers.complete_picture_next_check_in_word(anchor_at)
    @complete_picture_check_ins_url = organization_company_teammate_check_ins_path(organization, @teammate)
    @complete_picture_seats_management_url = organization_seats_path(organization)

    goals_arr = Goal.where(owner: @teammate, deleted_at: nil).includes(:goal_check_ins).to_a
    @complete_picture_goals_active_count = goals_arr.count { |g| g.started_at.present? && g.completed_at.nil? }
    @complete_picture_goals_health_status = Goals::HealthStatusCalculator.call(goals_arr)

    casual = @teammate.person.casual_name
    return_path = complete_picture_organization_company_teammate_path(organization, @teammate)
    @complete_picture_my_growth_goals_url = my_growth_goals_organization_company_teammate_path(organization, @teammate)
    @complete_picture_observations_index_url = organization_observations_path(
      organization,
      involving_teammate_id: @teammate.id,
      timeframe: 'all',
      return_url: return_path,
      return_text: "Back to #{casual}'s True Day-to-Day"
    )

    timeframe_all = { timeframe: 'all' }
    given_query = ObservationsQuery.new(
      organization,
      timeframe_all.merge(observer_id: @teammate.person_id, exclude_observer_as_observee: true),
      current_person: current_person
    )
    @complete_picture_observations_given_count = given_query.call.count

    received_query = ObservationsQuery.new(
      organization,
      timeframe_all.merge(observee_ids: [@teammate.id]),
      current_person: current_person
    )
    @complete_picture_observations_received_count = received_query.call.count

    involving_query = ObservationsQuery.new(
      organization,
      timeframe_all.merge(involving_teammate_id: @teammate.id),
      current_person: current_person
    )
    @complete_picture_recent_observations = involving_query.call
      .includes(:observer, { observed_teammates: :person }, :observation_ratings, :notifications)
      .limit(20)
      .to_a
    complete_picture_preload_observation_rateables!(@complete_picture_recent_observations)
  end

  # Same polymorphic preload as Organizations::ObservationsController#preload_rateables (large list ratings).
  def complete_picture_preload_observation_rateables!(observations)
    rating_ids_by_type = observations.flat_map(&:observation_ratings).group_by(&:rateable_type)
    rating_ids_by_type.each do |rateable_type, ratings|
      ids = ratings.map(&:rateable_id).uniq
      next if ids.empty?

      case rateable_type
      when 'Assignment'
        Assignment.where(id: ids).load
      when 'Ability'
        Ability.where(id: ids).load
      when 'Aspiration'
        Aspiration.where(id: ids).load
      end
    end
  end

  # Oldest "latest finalized" across position, assignment, and aspiration check-ins for this org (most urgent stream).
  def complete_picture_earliest_official_finalized_at
    times = []
    teammate = @teammate
    org = organization

    if (pci = PositionCheckIn.latest_finalized_for(teammate))&.official_check_in_completed_at
      times << pci.official_check_in_completed_at
    end

    AssignmentCheckIn
      .joins(:assignment)
      .where(company_teammate: teammate, assignments: { company_id: org.id })
      .closed
      .group(:assignment_id)
      .maximum(:official_check_in_completed_at)
      .each_value { |t| times << t if t }

    aspiration_ids = Aspiration.within_hierarchy(org).pluck(:id)
    if aspiration_ids.any?
      AspirationCheckIn
        .where(company_teammate: teammate, aspiration_id: aspiration_ids)
        .closed
        .group(:aspiration_id)
        .maximum(:official_check_in_completed_at)
        .each_value { |t| times << t if t }
    end

    times.compact.min
  end

  def load_my_growth_employment_context
    @employment_tenures = @teammate.employment_tenures
      .includes(:company, :position, :manager_teammate)
      .where(company: organization)
      .order(started_at: :desc)
      .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
  end

  def load_my_growth_ability_rows
    current_position = @current_employment&.position
    target_position = @teammate.next_goal_position

    if current_position
      current_position = Position.includes(
        { position_abilities: :ability },
        position_assignments: { assignment: { assignment_abilities: :ability } }
      ).find(current_position.id)
    end
    if target_position
      target_position = Position.includes(
        { position_abilities: :ability },
        position_assignments: { assignment: { assignment_abilities: :ability } }
      ).find(target_position.id)
    end

    @my_growth_ability_rows = MyGrowthAbilityMilestoneRows.build(
      teammate: @teammate,
      current_position: current_position,
      target_position: target_position
    )

    ability_ids = @my_growth_ability_rows.map { |r| r[:ability].id }.uniq
    @my_growth_ability_goal_counts_by_id = my_growth_ability_goal_counts_for_teammate(ability_ids)
  end

  def load_my_growth_experiences_rows
    @my_growth_show_suggested = ActiveModel::Type::Boolean.new.cast(params[:show_suggested])
    @my_growth_suggested_anchor = 'suggested-assignments-toggle'

    casual = @teammate.person.casual_name.presence || 'this teammate'
    current_position = @current_employment&.position
    target_position = @teammate.next_goal_position

    cur_req, cur_sug = my_growth_experiences_position_maps(current_position)
    tar_req, tar_sug = my_growth_experiences_position_maps(target_position)

    active_tenures = @teammate.assignment_tenures.active
      .joins(:assignment)
      .where(assignments: { company: organization })
      .includes(:assignment)
    sorted_active = active_tenures.sort_by do |t|
      e = t.anticipated_energy_percentage
      [e.nil? ? 1 : 0, -(e || 0), t.assignment.title.to_s.downcase]
    end

    active_by_assignment_id = sorted_active.index_by(&:assignment_id)
    active_ids = sorted_active.map(&:assignment_id)

    primary_ids = (active_ids + cur_req.keys + tar_req.keys).uniq
    suggested_only_ids = (cur_sug.keys + tar_sug.keys).uniq - primary_ids

    all_row_ids = (primary_ids + suggested_only_ids).uniq
    assignments_by_id = Assignment.where(id: all_row_ids).index_by(&:id)

    primary_active_order = sorted_active.map(&:assignment_id).select { |id| primary_ids.include?(id) }
    primary_inactive_ids = primary_ids - primary_active_order
    primary_inactive_sorted = primary_inactive_ids.sort_by do |aid|
      pa = cur_req[aid] || tar_req[aid]
      a = assignments_by_id[aid]
      e = pa&.anticipated_energy_percentage
      [e.nil? ? 1 : 0, -(e || 0), (a&.title || '').to_s.downcase]
    end

    @my_growth_experience_primary_rows = []
    (primary_active_order + primary_inactive_sorted).each do |aid|
      row = my_growth_experience_build_row(
        aid,
        tenure: active_by_assignment_id[aid],
        assignments_by_id: assignments_by_id,
        casual_name: casual,
        current_position: current_position,
        target_position: target_position,
        cur_req: cur_req, cur_sug: cur_sug,
        tar_req: tar_req, tar_sug: tar_sug,
        section: :primary
      )
      @my_growth_experience_primary_rows << row if row
    end

    suggested_only_sorted = suggested_only_ids.sort_by do |aid|
      pa = cur_sug[aid] || tar_sug[aid]
      a = assignments_by_id[aid]
      e = pa&.anticipated_energy_percentage
      [e.nil? ? 1 : 0, -(e || 0), (a&.title || '').to_s.downcase]
    end

    @my_growth_experience_suggested_rows = []
    if @my_growth_show_suggested
      suggested_only_sorted.each do |aid|
        row = my_growth_experience_build_row(
          aid,
          tenure: active_by_assignment_id[aid],
          assignments_by_id: assignments_by_id,
          casual_name: casual,
          current_position: current_position,
          target_position: target_position,
          cur_req: cur_req, cur_sug: cur_sug,
          tar_req: tar_req, tar_sug: tar_sug,
          section: :suggested
        )
        @my_growth_experience_suggested_rows << row if row
      end
    end

    @my_growth_suggested_toggle_visible = suggested_only_ids.any?

    assignment_ids = sorted_active.map(&:assignment_id).uniq
    @latest_finalized_assignment_check_ins_by_assignment_id = {}
    if assignment_ids.any?
      AssignmentCheckIn
        .where(company_teammate: @teammate, assignment_id: assignment_ids)
        .closed
        .includes(:assignment, manager_completed_by_teammate: :person, finalized_by_teammate: :person)
        .order(official_check_in_completed_at: :desc)
        .each do |check_in|
          @latest_finalized_assignment_check_ins_by_assignment_id[check_in.assignment_id] ||= check_in
        end
    end

    assignment_ids_for_goal_links = sorted_active.map(&:assignment_id).uniq
    @my_growth_assignment_goal_counts_by_id = my_growth_assignment_goal_counts_for_teammate(assignment_ids_for_goal_links)

    @my_growth_experiences_summary = MyGrowth::ExperiencesSummary.build(
      teammate: @teammate,
      latest_finalized_check_ins_by_assignment_id: @latest_finalized_assignment_check_ins_by_assignment_id
    )
  end

  def my_growth_experiences_position_maps(position)
    required = {}
    suggested = {}
    return [required, suggested] if position.blank?

    position.position_assignments.includes(:assignment).each do |pa|
      if pa.assignment_type == 'required'
        required[pa.assignment_id] = pa
      elsif pa.assignment_type == 'suggested'
        suggested[pa.assignment_id] = pa
      end
    end
    [required, suggested]
  end

  def my_growth_experiences_variant(required_h, suggested_h, assignment_id)
    if required_h[assignment_id]
      [:required, required_h[assignment_id]]
    elsif suggested_h[assignment_id]
      [:suggested, suggested_h[assignment_id]]
    else
      [:unique, nil]
    end
  end

  def my_growth_experiences_not_assigned_pill(section, assignment_id, active,
                                              cur_req, tar_req, cur_sug, tar_sug,
                                              current_position, target_position)
    return [nil, nil] if active

    if section == :primary
      if cur_req[assignment_id] && current_position
        [:required, current_position.display_name]
      elsif tar_req[assignment_id] && target_position
        [:required, target_position.display_name]
      else
        [:required, nil]
      end
    elsif cur_sug[assignment_id] && current_position
      [:suggested, current_position.display_name]
    elsif tar_sug[assignment_id] && target_position
      [:suggested, target_position.display_name]
    else
      [:suggested, nil]
    end
  end

  def my_growth_experience_build_row(assignment_id, tenure:, assignments_by_id:, casual_name:,
                                     current_position:, target_position:,
                                     cur_req:, cur_sug:, tar_req:, tar_sug:, section:)
    assignment = tenure&.assignment || assignments_by_id[assignment_id]
    return if assignment.blank?

    active = tenure.present?
    cur_var, cur_pa = my_growth_experiences_variant(cur_req, cur_sug, assignment_id)
    tar_var, tar_pa = my_growth_experiences_variant(tar_req, tar_sug, assignment_id)

    col1_kind = if active
                  :active
                elsif section == :primary
                  :warning_required
                else
                  :warning_suggested
                end

    pill_kind, pill_position = my_growth_experiences_not_assigned_pill(
      section, assignment_id, active,
      cur_req, tar_req, cur_sug, tar_sug,
      current_position, target_position
    )

    {
      assignment: assignment,
      tenure: tenure,
      casual_name: casual_name,
      section: section,
      col1_kind: col1_kind,
      not_assigned_pill_kind: pill_kind,
      not_assigned_pill_position_name: pill_position,
      current_variant: cur_var,
      current_pa: cur_pa,
      target_variant: tar_var,
      target_pa: tar_pa
    }
  end

  def my_growth_assignment_goal_counts_for_teammate(assignment_ids)
    return {} if assignment_ids.blank?

    base = Goal.joins(:goal_associations)
      .where(goal_associations: { associable_type: 'Assignment', associable_id: assignment_ids })
      .where(owner_type: 'CompanyTeammate', owner_id: @teammate.id)

    open_by_id = base.merge(Goal.incomplete_unarchived).group('goal_associations.associable_id').count

    assignment_ids.index_with do |aid|
      { open_associated_goals_count: open_by_id[aid] || 0 }
    end
  end

  def my_growth_ability_goal_counts_for_teammate(ability_ids)
    return {} if ability_ids.blank?

    base = Goal.joins(:goal_associations)
      .where(goal_associations: { associable_type: 'Ability', associable_id: ability_ids })
      .where(owner_type: 'CompanyTeammate', owner_id: @teammate.id)

    open_by_id = base.merge(Goal.incomplete_unarchived).group('goal_associations.associable_id').count

    ability_ids.index_with do |aid|
      { open_associated_goals_count: open_by_id[aid] || 0 }
    end
  end

  def load_my_growth_positions_by_department
    co = organization.root_company || organization
    positions = Position.joins(title: :company)
      .where(titles: { company_id: co.id })
      .includes(:title, :position_level)
      .ordered
    @positions_by_department = positions.group_by { |pos| pos.title.department || co }
  end

  def load_bulk_confidence_check_goals
    viewing_teammate = current_company_teammate
    return unless viewing_teammate

    @bulk_check_in_goals = Goals::BulkCheckInGoalsScopeQuery.new(
      teammate: @teammate,
      organization: organization,
      viewing_teammate: viewing_teammate
    ).call

    @bulk_check_in_hierarchy = if @bulk_check_in_goals.any?
      Goals::HierarchyWithCheckInsQuery.new(
        goals: @bulk_check_in_goals,
        current_person: current_person,
        organization: organization
      ).call
    else
      { root_goals: [], most_recent_check_ins_by_goal: {}, current_week_check_ins_by_goal: {}, can_check_in_goals: Set.new }
    end
  end

  def my_growth_parse_timeframe(param)
    case param.to_s
    when 'year' then :year
    when 'all_time' then :all_time
    else :'90_days'
    end
  end

  def my_growth_date_range_for(timeframe)
    case timeframe
    when :'90_days'
      90.days.ago..Time.current
    when :year
      1.year.ago..Time.current
    when :all_time
      nil
    else
      90.days.ago..Time.current
    end
  end

  def my_growth_chart_title_period(timeframe)
    case timeframe
    when :'90_days' then 'Last 90 Days'
    when :year then 'Last Year'
    when :all_time then 'Last 52 Weeks'
    else 'Last 90 Days'
    end
  end

  def set_teammate
    @teammate = find_organization_teammate!(params[:id])
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
      check_ins: AssignmentCheckIn.joins(:company_teammate).where(company_teammate: @teammate, assignments: { company: organization }).includes(:assignment),
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
      
      open_check_in = AssignmentCheckIn.where(company_teammate: @teammate, assignment: assignment).open.first
      
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
                                  .where(company_teammate: @teammate, assignments: { company: organization })
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
    current_check_in = AssignmentCheckIn.where(company_teammate: @teammate, assignment: assignment).open.first
    
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
    assign_viewable_teammates_context!(selected_teammate: @teammate)
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
    HuddleParticipant.joins(:company_teammate)
                    .where(teammates: { id: @teammate.id, organization: organization })
                    .includes(:huddle, huddle: :team)
                    .load
    HuddleFeedback.joins(:company_teammate)
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
      # Only goals where this teammate is the owner (same scope for list and collapsed alert)
      base_goals = Goal.where(owner: @teammate).active.includes(:goal_check_ins)
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

      # Order goals hierarchically: each parent immediately followed by its children (then their children).
      # Roots are sorted by date day then title (same as goal index); children under a parent same.
      links = GoalLink.where(parent_id: goal_ids, child_id: goal_ids)
      child_ids_in_set = links.pluck(:child_id).uniq.to_set
      root_ids = goal_ids.reject { |id| child_ids_in_set.include?(id) }
      parent_to_children = links.group_by(&:parent_id).transform_values { |rows| rows.map(&:child_id).uniq }
      goals_by_id = all_active_goals.index_by(&:id)
      sort_key = ->(id) {
        g = goals_by_id[id]
        [(g&.most_likely_target_date&.day) || 99, (g&.title&.downcase) || '']
      }
      sorted_root_ids = root_ids.sort_by { |id| sort_key[id] }
      ordered_ids = []
      append_subtree = lambda do |parent_id|
        (parent_to_children[parent_id] || []).sort_by { |id| sort_key[id] }.each do |child_id|
          ordered_ids << child_id
          append_subtree.call(child_id)
        end
      end
      sorted_root_ids.each do |root_id|
        ordered_ids << root_id
        append_subtree.call(root_id)
      end
      @about_me_goals_ordered = ordered_ids.map { |id| goals_by_id[id] }.compact
      # Goals that are children of another goal in this set (for prefix icon in view)
      child_ids = GoalLink.where(parent_id: goal_ids, child_id: goal_ids).pluck(:child_id).uniq
      @about_me_goal_child_ids = Set.new(child_ids)
      
      # Check if any goals were completed in the last 90 days (for status indicator)
      @goals_completed_recently = base_goals.where('completed_at >= ?', 90.days.ago).exists?
      
      # Calculate goals with check-ins in the past two weeks
      cutoff_week = (Date.current - 14.days).beginning_of_week(:monday)
      recent_check_in_goal_ids = all_check_ins
        .select { |check_in| check_in.check_in_week_start >= cutoff_week }
        .map(&:goal_id)
        .uniq
      @goals_with_recent_check_ins_count = all_active_goals.count { |goal| recent_check_in_goal_ids.include?(goal.id) }
      
      # Calculate goals completed in the last 90 days (owner-only, same scope as list)
      @goals_completed_count = Goal.where(owner: @teammate)
        .where('completed_at >= ?', 90.days.ago)
        .where(deleted_at: nil)
        .count

      # Calculate draft goals count (owner-only, same scope as list)
      @draft_goals_count = Goal.where(owner: @teammate)
        .draft
        .where(deleted_at: nil)
        .count
      
      @goals_check_in_url = organization_goals_path(
        organization,
        owner_type: 'CompanyTeammate',
        owner_id: @teammate.id,
        view: 'hierarchical-collapsible'
      )
    else
      @now_goals = []
      @next_goals = []
      @later_goals = []
      @about_me_goals_ordered = []
      @about_me_goal_child_ids = Set.new
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
    active_tenure = @teammate.active_employment_tenure
    @position_display_name_for_assignments = active_tenure&.position&.display_name || "undefined position"
    
    relevant_assignments = helpers.relevant_assignments_for_about_me(@teammate, organization)
    @required_assignments = relevant_assignments.to_a

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
    
    relevant_assignment_ids = @required_assignments.map(&:id)

    # Batch-load most-recent tenure per assignment (avoids N+1 from find_or_create_open_for)
    tenures_by_assignment = {}
    AssignmentTenure.where(teammate_id: @teammate.id, assignment_id: relevant_assignment_ids)
                    .order(started_at: :desc)
                    .each { |t| tenures_by_assignment[t.assignment_id] ||= t }

    # Batch-load open check-ins per assignment
    open_check_ins_by_assignment = AssignmentCheckIn
      .where(company_teammate: @teammate, assignment_id: relevant_assignment_ids)
      .open
      .index_by(&:assignment_id)

    # Batch-load latest finalized check-in per assignment
    finalized_by_assignment = {}
    AssignmentCheckIn
      .where(company_teammate: @teammate, assignment_id: relevant_assignment_ids)
      .closed
      .order(official_check_in_completed_at: :desc)
      .each { |ci| finalized_by_assignment[ci.assignment_id] ||= ci }

    cutoff_date = 90.days.ago
    active_goal_counts_by_assignment_id = Goal
      .active
      .where(owner: @teammate)
      .joins(:goal_associations)
      .where(goal_associations: { associable_type: 'Assignment', associable_id: relevant_assignment_ids })
      .group('goal_associations.associable_id')
      .count

    @assignment_check_ins_data = relevant_assignments.map do |assignment|
      tenure = tenures_by_assignment[assignment.id]
      check_in = open_check_ins_by_assignment[assignment.id]
      latest_finalized = finalized_by_assignment[assignment.id]

      if check_in.nil? && tenure
        check_in = AssignmentCheckIn.create!(
          company_teammate: @teammate,
          assignment: assignment,
          check_in_started_on: Date.current,
          actual_energy_percentage: tenure.anticipated_energy_percentage
        )
      end

      {
        assignment: assignment,
        position_assignment: required_assignments_map[assignment.id],
        assignment_tenure: active_tenures_map[assignment.id],
        check_in: check_in,
        latest_finalized: latest_finalized,
        latest_rating: about_me_latest_rating_for_check_in(latest_finalized),
        has_active_goal: active_goal_counts_by_assignment_id[assignment.id].to_i.positive?
      }
    end
    
    @assignments_with_recent_check_ins_count = @assignment_check_ins_data.count do |data|
      data[:latest_finalized] && data[:latest_finalized].official_check_in_completed_at >= cutoff_date
    end
  end

  def load_aspiration_check_in_data
    # Get all company aspirational values
    @company_aspirations = Aspiration.within_hierarchy(organization).ordered
    @company_name = organization.root_company&.name || organization.name
    
    cutoff_date = 90.days.ago
    aspiration_ids = @company_aspirations.map(&:id)
    active_goal_counts_by_aspiration_id = Goal
      .active
      .where(owner: @teammate)
      .joins(:goal_associations)
      .where(goal_associations: { associable_type: 'Aspiration', associable_id: aspiration_ids })
      .group('goal_associations.associable_id')
      .count

    @aspiration_check_ins_data = @company_aspirations.map do |aspiration|
      check_in = AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
      latest_finalized = AspirationCheckIn
        .where(company_teammate: @teammate, aspiration: aspiration)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      {
        aspiration: aspiration,
        check_in: check_in,
        latest_finalized: latest_finalized,
        latest_rating: about_me_latest_rating_for_check_in(latest_finalized),
        has_active_goal: active_goal_counts_by_aspiration_id[aspiration.id].to_i.positive?
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
      position = active_tenure.position
      @required_assignments_for_abilities = position.required_assignments.includes(assignment: :assignment_abilities)
      @position_display_name_for_abilities = position.display_name

      # Collect all ability milestones (from assignments and position direct)
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

      # Add position direct milestone requirements block
      position.position_abilities.includes(:ability).each do |position_ability|
        ability = position_ability.ability
        teammate_milestone = @teammate.teammate_milestones.find_by(ability: ability)
        current_milestone = teammate_milestone&.milestone_level || 0
        required_milestone = position_ability.milestone_level

        all_ability_milestones << {
          ability: ability,
          required_milestone: required_milestone,
          current_milestone: current_milestone,
          met: current_milestone >= required_milestone
        }
      end

      if position.position_abilities.any?
        position_abilities_info = position.position_abilities.includes(:ability).map do |position_ability|
          ability = position_ability.ability
          teammate_milestone = @teammate.teammate_milestones.find_by(ability: ability)
          current_milestone = teammate_milestone&.milestone_level || 0
          {
            ability: ability,
            required_milestone: position_ability.milestone_level,
            current_milestone: current_milestone
          }
        end
        @abilities_data << {
          position_direct: true,
          label: 'Position (direct)',
          abilities: position_abilities_info,
          fully_qualified: position_abilities_info.all? { |info| info[:current_milestone] >= info[:required_milestone] }
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

  def about_me_latest_rating_for_check_in(check_in)
    return nil unless check_in

    check_in.official_rating.presence || check_in.manager_rating.presence || check_in.employee_rating.presence
  end

end


