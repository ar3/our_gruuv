class Organizations::EmployeesController < Organizations::OrganizationNamespaceBaseController
  include TeammateHelper
  
  before_action :require_authentication
  after_action :verify_authorized
  
  def index
    # Initialize spotlight_stats to ensure it's always set
    @spotlight_stats = {}
    
    # Basic authorization - user should be able to view the organization
    authorize @organization, :show?
    
    # Handle preset application (if preset is selected and no discrete options changed)
    apply_preset_if_selected
    
    # Set default status to 'active' only when status is nil (not when it's an empty string)
    # This allows the UI to explicitly request other statuses
    params[:status] = 'active' if params[:status].nil?
    
    # Additional authorization for manager filter
    if params[:manager_filter] == 'direct_reports' && (!current_company_teammate || !current_company_teammate.has_direct_reports?)
      redirect_to organization_employees_path(@organization), 
                  alert: 'You do not have any direct reports in this organization.'
      return
    end
    
    # Determine spotlight type
    @current_spotlight = determine_spotlight
    
    # Use TeammatesQuery for filtering and sorting
    query = TeammatesQuery.new(@organization, params, current_person: current_person)
    
    # Get teammates with all filters except status (to keep ActiveRecord relation)
    filtered_teammates = query.call
    
    # Handle vertical_hierarchy view
    if query.current_view == 'vertical_hierarchy'
      # Build hierarchy tree
      hierarchy_query = VerticalHierarchyQuery.new(organization: @organization)
      full_hierarchy_tree = hierarchy_query.call
      
      # Get filtered teammates with all filters applied
      status_filtered_teammates = query.filter_by_status(filtered_teammates)
      filtered_teammates_array = status_filtered_teammates.is_a?(Array) ? status_filtered_teammates : status_filtered_teammates.to_a
      
      # Get person IDs from filtered teammates
      filtered_person_ids = filtered_teammates_array.map { |t| t.person_id }.to_set
      
      # Filter hierarchy tree to only include nodes matching filters
      @hierarchy_tree = filter_hierarchy_tree(full_hierarchy_tree, filtered_person_ids)
      
      # Find unassigned teammates matching filters
      org_ids = @organization.company? ? @organization.self_and_descendants.map(&:id) : [@organization.id]
      teammates_with_active_tenures = EmploymentTenure.active
                                                       .joins(:teammate)
                                                       .where(company_id: org_ids)
                                                       .where(teammates: { organization_id: org_ids })
                                                       .select('DISTINCT teammates.id')
      
      # Start with unassigned teammates query
      unassigned_base = Teammate.where(organization_id: org_ids)
                                .where(type: 'CompanyTeammate')
                                .where.not(id: teammates_with_active_tenures)
                                .where.not(first_employed_at: nil)
                                .where(last_terminated_at: nil)
                                .includes(:person)
                                .joins(:person)
      
      # Apply the same filters from TeammatesQuery manually (since methods are private)
      # Filter by organization
      if params[:organization_id].present?
        org_id = params[:organization_id].to_i
        filter_org = Organization.find(org_id)
        unassigned_base = unassigned_base.where(organization: filter_org.self_and_descendants)
      end
      
      # Filter by permissions
      if params[:permission].present?
        permissions = Array(params[:permission])
        permissions.each do |permission|
          case permission
          when 'employment_mgmt'
            unassigned_base = unassigned_base.where(can_manage_employment: true)
          when 'employment_create'
            unassigned_base = unassigned_base.where(can_create_employment: true)
          when 'maap_mgmt'
            unassigned_base = unassigned_base.where(can_manage_maap: true)
          end
        end
      end
      
      # Filter by manager relationship
      if params[:manager_filter] == 'direct_reports' && current_person
        unassigned_base = unassigned_base.joins(:employment_tenures)
                                         .where(employment_tenures: { manager: current_person, ended_at: nil })
                                         .distinct
      end
      
      # Apply status filter
      @unassigned_teammates = query.filter_by_status(unassigned_base)
      
      # Store filtered teammates for spotlight calculations
      @filtered_teammates = filtered_teammates_array
      
      # Calculate spotlight statistics
      filtered_teammates_for_joins = filtered_teammates
      if @current_spotlight == 'employee_locations'
        filtered_teammates_for_joins = filtered_teammates_for_joins.includes(person: :addresses) if filtered_teammates_for_joins.respond_to?(:includes)
      end
      @spotlight_stats = calculate_spotlight_stats(@filtered_teammates, @current_spotlight, filtered_teammates_for_joins)
      
      # Disable pagination for hierarchy view
      unassigned_count = @unassigned_teammates.is_a?(Array) ? @unassigned_teammates.count : @unassigned_teammates.count
      @pagy = Pagy.new(count: @hierarchy_tree.count + unassigned_count, page: 1, items: 999999)
      @filtered_and_paginated_teammates = []
    # Handle check_ins_health view
    elsif query.current_view == 'check_ins_health'
      # Filter to active employees only for check-ins health
      filtered_teammates = filtered_teammates.where.not(first_employed_at: nil).where(last_terminated_at: nil)
      
      # Create filtered_teammates: filtered but unpaginated (for spotlight calculations)
      @filtered_teammates = filtered_teammates
      
      # Calculate health data for all active employees
      all_employee_health_data = @filtered_teammates.map do |teammate|
        health_data = CheckInHealthService.call(teammate, @organization)
        {
          teammate: teammate,
          person: teammate.person,
          health: health_data
        }
      end
      
      # Calculate spotlight statistics from all data (before pagination)
      @spotlight_stats = calculate_check_ins_health_stats(all_employee_health_data)
      
      # Paginate
      @pagy = Pagy.new(count: all_employee_health_data.count, page: params[:page] || 1, items: 25)
      @filtered_and_paginated_employee_health_data = all_employee_health_data[@pagy.offset, @pagy.items]
      @filtered_and_paginated_teammates = [] # Empty for check_ins_health view
    else
      # Eager load associations for check-in status display BEFORE pagination to preserve filters
      if query.current_view == 'check_in_status'
        filtered_teammates = eager_load_check_in_data(filtered_teammates)
      end
      
      # Apply status filter (converts to Array if granular statuses are used)
      status_filtered_teammates = query.filter_by_status(filtered_teammates)
      
      # Create filtered_teammates: filtered but unpaginated (for spotlight calculations)
      # Keep as Array if that's what filter_by_status returned, otherwise keep as relation
      @filtered_teammates = status_filtered_teammates
      
      # Paginate the status-filtered teammates (for display)
      @pagy = Pagy.new(count: status_filtered_teammates.count, page: params[:page] || 1, items: 25)
      @filtered_and_paginated_teammates = status_filtered_teammates[@pagy.offset, @pagy.items]
      
      # For spotlight calculations, we need the original relation (before status filtering) for joins
      # but use filtered_teammates for counts. Pass both to calculate_spotlight_stats.
      filtered_teammates_for_joins = filtered_teammates
      
      # Eager load associations on filtered_teammates_for_joins as needed (for spotlight calculations)
      if @current_spotlight == 'employee_locations'
        filtered_teammates_for_joins = filtered_teammates_for_joins.includes(person: :addresses)
      end
      
      # Calculate spotlight statistics from filtered_teammates (honors filters, not pagination)
      # Pass both filtered array and original relation for proper join calculations
      @spotlight_stats = calculate_spotlight_stats(@filtered_teammates, @current_spotlight, filtered_teammates_for_joins)
    end
    
    # Store current filter/sort state for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @has_active_filters = query.has_active_filters?
  end

  def customize_view
    # Authorization: require ability to view organization
    authorize @organization, :show?
    
    # Load current state from params or defaults
    query = TeammatesQuery.new(@organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = determine_spotlight
    @has_active_filters = query.has_active_filters?
    
    # Preserve current params for return URL (excluding controller/action/page)
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_employees_path(@organization, return_params)
    @return_text = "Back to Teammates"
    
    render layout: 'overlay'
  end

  def update_view
    # Authorization: require ability to view organization
    authorize @organization, :show?
    
    # Handle preset application if selected
    apply_preset_if_selected
    
    # Build redirect URL with all the view customization params
    # Preserve all params except Rails internal ones
    redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h.compact
    
    redirect_to organization_employees_path(@organization, redirect_params), notice: 'View updated successfully.'
  end

  def new_employee
    # For creating a new person and employment simultaneously
    authorize @organization, :manage_employment?
    @person = Person.new
    @employment_tenure = EmploymentTenure.new
    @positions = @organization.positions.includes(:position_type, :position_level)
    @managers = @organization.employees
  end

  def create_employee
    # For creating a new person and employment simultaneously
    authorize @organization, :manage_employment?
    
    # Create person and employment in a transaction
    ActiveRecord::Base.transaction do
      @person = Person.new(person_params)
      @person.save!
      
      # Create teammate for this person and organization
      teammate = @person.teammates.create!(
        organization: @organization,
        type: 'CompanyTeammate'
      )
      
      @employment_tenure = teammate.employment_tenures.build(employment_tenure_params)
      @employment_tenure.company = @organization
      @employment_tenure.teammate = teammate
      @employment_tenure.save!
      
      redirect_to organization_person_path(@organization, @person), notice: 'Employee was successfully created.'
    end
  rescue ActiveRecord::RecordInvalid
    @positions = @organization.positions.includes(:position_type, :position_level)
    @managers = @organization.employees
    render :new_employee, status: :unprocessable_entity
  end

  def audit
    # Initialize maap_snapshots to ensure it's always set
    @maap_snapshots = MaapSnapshot.none
    
    # Route now uses teammate ID (migrated from person ID)
    # Try to find teammate first, then get person from teammate
    @teammate = @organization.teammates.find_by(id: params[:id])
    if @teammate
      @person = @teammate.person
    else
      # Fallback: try to find by person ID for backward compatibility
      @person = @organization.employees.find(params[:id])
      @teammate = @organization.teammates.find_by(person: @person)
    end
    
    # Authorize access to audit view (organization context passed via pundit_user)
    authorize @teammate, :audit?, policy_class: CompanyTeammatePolicy
    
    # Get MAAP snapshots for this person within this organization
    @maap_snapshots = MaapSnapshot.for_employee(@person)
                                  .for_company(@organization)
                                  .recent
                                  .includes(:created_by)
    
    # Separate acknowledged and pending snapshots for employee view
    if current_person == @person
      @acknowledged_snapshots = @maap_snapshots.where.not(employee_acknowledged_at: nil)
      @pending_snapshots = @maap_snapshots.where(employee_acknowledged_at: nil).where.not(effective_date: nil)
    end
  end
  
  def acknowledge_snapshots
    # Find the person/employee
    @person = @organization.employees.find(params[:id])
    
    # Authorize access to audit view
    authorize @person, :audit?, policy_class: PersonPolicy
    
    # Only allow employees to acknowledge their own snapshots
    unless current_person == @person
      redirect_to audit_organization_employee_path(@organization, @person), 
                  alert: 'You can only acknowledge your own check-ins.'
      return
    end
    
    # Get selected snapshot IDs
    snapshot_ids = params[:snapshot_ids] || []
    
    if snapshot_ids.empty?
      redirect_to audit_organization_employee_path(@organization, @person), 
                  alert: 'Please select at least one check-in to acknowledge.'
      return
    end
    
    # Find and acknowledge the snapshots
    snapshots = MaapSnapshot.where(id: snapshot_ids, employee: @person).where.not(effective_date: nil)
    
    acknowledged_count = 0
    snapshots.each do |snapshot|
      unless snapshot.acknowledged?
        snapshot.update!(
          employee_acknowledged_at: Time.current,
          employee_acknowledgement_request_info: {
            acknowledged_by: current_person.id,
            acknowledged_at: Time.current,
            request_source: 'audit_page'
          }
        )
        acknowledged_count += 1
      end
    end
    
    redirect_to audit_organization_employee_path(@organization, @person), 
                notice: "Successfully acknowledged #{acknowledged_count} check-in#{'s' if acknowledged_count != 1}."
  end
  
  private

    def apply_preset_if_selected
      return unless params[:preset].present?
      
      # Check if user has modified any discrete options (if so, ignore preset)
      # For now, we'll apply preset immediately as specified
      preset_params = preset_to_params(params[:preset])
      
      if preset_params
        preset_params.each do |key, value|
          # Only override if the param wasn't explicitly set by user
          # For presets, we override everything
          params[key] = value
        end
      end
    end

    def preset_to_params(preset_name)
      case preset_name.to_s
      when 'my_direct_reports_check_in_status_1'
        {
          display: 'check_in_status',
          manager_filter: 'direct_reports'
        }
      when 'my_direct_reports_check_in_status_2'
        {
          display: 'check_ins_health',
          spotlight: 'check_ins_health',
          manager_filter: 'direct_reports'
        }
      when 'all_employees_check_in_status_1'
        {
          display: 'check_in_status',
          status: 'active'
        }
      when 'all_employees_check_in_status_2'
        {
          display: 'check_ins_health',
          spotlight: 'check_ins_health',
          status: 'active'
        }
      when 'hierarchical_accountability_chart'
        {
          view: 'vertical_hierarchy',
          status: ['unassigned_employee', 'assigned_employee'],
          organization_id: @organization.id,
          spotlight: 'manager_distribution'
        }
      else
        nil
      end
    end

    def determine_spotlight
      # If spotlight param is set, use it
      return params[:spotlight] if params[:spotlight].present?
      
      # Auto-select manager_overview if manager filter is active
      return 'manager_overview' if params[:manager_filter] == 'direct_reports'
      
      # Default to teammates_overview (matches TeammatesQuery default)
      'teammates_overview'
    end

    def eager_load_check_in_data(teammates)
      # Convert array back to ActiveRecord relation for eager loading if needed
      if teammates.is_a?(Array)
        teammate_ids = teammates.map(&:id)
        teammates_relation = Teammate.where(id: teammate_ids)
      else
        teammates_relation = teammates
      end
      
      # Eager load all check-in related associations
      # Note: assignment_check_ins and aspiration_check_ins belong directly to teammate, not through assignment_tenures
      teammates_relation.includes(
        :person,
        :employment_tenures => [:position_check_ins, :position],
        :assignment_tenures => :assignment, # assignment_tenures has assignment, but check-ins are on teammate
        :assignment_check_ins => :assignment, # assignment_check_ins belong to teammate directly
        :aspiration_check_ins => :aspiration, # aspiration_check_ins belong to teammate directly
        :teammate_milestones => :ability
      )
    end

    def calculate_spotlight_stats(teammates, spotlight_type = nil, teammates_for_joins = nil)
      spotlight_type ||= determine_spotlight
      
      # Use teammates_for_joins if provided (original relation before status filtering), otherwise use teammates
      teammates_for_joins ||= teammates
      
      case spotlight_type
      when 'check_ins_health'
        # This should not be called for check_ins_health spotlight
        # Use calculate_check_ins_health_stats instead
        {}
      when 'teammate_tenures'
        calculate_tenure_stats(teammates)
      when 'employee_locations'
        calculate_location_stats(teammates)
      when 'manager_overview'
        calculate_manager_overview_stats(teammates, teammates_for_joins)
      when 'manager_distribution'
        calculate_manager_distribution_stats(teammates, teammates_for_joins)
      else # 'teammates_overview' or default
        calculate_teammates_overview_stats(teammates, teammates_for_joins)
      end
    end

    def calculate_teammates_overview_stats(teammates, teammates_for_joins = nil)
      # Use teammates_for_joins for joins (original relation before status filtering)
      # Use teammates for counts (filtered array/relation)
      teammates_for_joins ||= teammates
      
      # Ensure teammates_for_joins is a relation for proper joins
      if teammates_for_joins.is_a?(Array)
        teammate_ids = teammates_for_joins.map(&:id)
        teammates_relation = Teammate.where(id: teammate_ids)
      else
        teammates_relation = teammates_for_joins
      end

      {
        total_teammates: teammates.count,
        followers: teammates.select { |t| TeammateStatus.new(t).status == :follower }.count,
        huddlers: teammates.select { |t| TeammateStatus.new(t).status == :huddler }.count,
        unassigned_employees: teammates.select { |t| TeammateStatus.new(t).status == :unassigned_employee }.count,
        assigned_employees: teammates.select { |t| TeammateStatus.new(t).status == :assigned_employee }.count,
        terminated: teammates.select { |t| TeammateStatus.new(t).status == :terminated }.count,
        unknown: teammates.select { |t| TeammateStatus.new(t).status == :unknown }.count,
        huddle_participants: teammates_relation.joins(:huddle_participants).distinct.count,
        non_employee_participants: teammates_relation.joins(:huddle_participants).where(first_employed_at: nil).distinct.count
      }
    end

    def calculate_manager_overview_stats(teammates, teammates_for_joins = nil)
      # Use teammates_for_joins for joins (original relation before status filtering)
      teammates_for_joins ||= teammates
      
      # Always use ActiveRecord relation for spotlight stats to ensure proper joins
      if teammates_for_joins.is_a?(Array)
        # Convert Array back to ActiveRecord relation for proper joins
        teammate_ids = teammates_for_joins.map(&:id)
        teammates_relation = Teammate.where(id: teammate_ids)
      else
        teammates_relation = teammates_for_joins
      end

      manager_stats = calculate_manager_stats(teammates, teammates_relation)
      calculate_teammates_overview_stats(teammates, teammates_for_joins).merge(manager_stats)
    end

    def calculate_tenure_stats(teammates)
      helpers.calculate_tenure_distribution(teammates)
    end

    def calculate_location_stats(teammates)
      helpers.calculate_location_distribution(teammates)
    end

    def calculate_check_ins_health_stats(employee_health_data)
      total_employees = employee_health_data.count
      
      # Count employees with all concerns healthy (all success or no requirements)
      all_healthy = employee_health_data.count do |data|
        health = data[:health]
        health[:position][:status] == :success &&
        (health[:assignments][:status] == :success || health[:assignments][:total_count] == 0) &&
        (health[:aspirations][:status] == :success || health[:aspirations][:total_count] == 0) &&
        (health[:milestones][:status] == :success || health[:milestones][:required_count] == 0)
      end
      
      # Count employees needing attention (any alarm or warning)
      needing_attention = employee_health_data.count do |data|
        health = data[:health]
        [:alarm, :warning].include?(health[:position][:status]) ||
        [:alarm, :warning].include?(health[:assignments][:status]) ||
        [:alarm, :warning].include?(health[:aspirations][:status]) ||
        [:alarm, :warning].include?(health[:milestones][:status])
      end
      
      # Calculate average check-in completion rate
      total_concerns = 0
      completed_concerns = 0
      
      employee_health_data.each do |data|
        health = data[:health]
        
        # Position
        total_concerns += 1
        completed_concerns += 1 if health[:position][:status] == :success
        
        # Assignments
        if health[:assignments][:total_count] > 0
          total_concerns += 1
          completed_concerns += 1 if health[:assignments][:status] == :success
        end
        
        # Aspirations
        if health[:aspirations][:total_count] > 0
          total_concerns += 1
          completed_concerns += 1 if health[:aspirations][:status] == :success
        end
        
        # Milestones
        if health[:milestones][:required_count] > 0
          total_concerns += 1
          completed_concerns += 1 if health[:milestones][:status] == :success
        end
      end
      
      completion_rate = total_concerns > 0 ? (completed_concerns.to_f / total_concerns * 100).round(1) : 0
      
      {
        total_employees: total_employees,
        all_healthy: all_healthy,
        needing_attention: needing_attention,
        completion_rate: completion_rate
      }
    end

    def calculate_manager_stats(teammates, teammates_relation)
      total_direct_reports = teammates.count
      ready_for_finalization = 0
      needs_manager_completion = 0
      pending_acknowledgements = 0
      total_check_ins = 0

      teammates.each do |teammate|
        # Count check-ins ready for finalization
        ready_count = helpers.ready_for_finalization_count(teammate.person, @organization)
        ready_for_finalization += ready_count

        # Count check-ins needing manager completion
        check_ins = helpers.check_ins_for_employee(teammate.person, @organization)
        needs_manager_completion += check_ins[:needs_manager_completion].count
        total_check_ins += check_ins[:position].count + check_ins[:assignments].count + check_ins[:aspirations].count

        # Count pending acknowledgements
        pending_acknowledgements += helpers.pending_acknowledgements_count(teammate.person, @organization)
      end

      # Calculate percentages
      completion_percentage = total_check_ins > 0 ? ((total_check_ins - needs_manager_completion - ready_for_finalization) * 100.0 / total_check_ins).round(1) : 0
      ready_percentage = total_check_ins > 0 ? (ready_for_finalization * 100.0 / total_check_ins).round(1) : 0
      incomplete_percentage = total_check_ins > 0 ? (needs_manager_completion * 100.0 / total_check_ins).round(1) : 0

      # Calculate team health score (simplified)
      team_health_score = if total_direct_reports > 0
        completion_rate = completion_percentage
        acknowledgement_rate = pending_acknowledgements > 0 ? 0 : 100
        ((completion_rate + acknowledgement_rate) / 2).round(0)
      else
        0
      end

      {
        total_direct_reports: total_direct_reports,
        ready_for_finalization: ready_for_finalization,
        needs_manager_completion: needs_manager_completion,
        pending_acknowledgements: pending_acknowledgements,
        total_check_ins: total_check_ins,
        completion_percentage: completion_percentage,
        ready_percentage: ready_percentage,
        incomplete_percentage: incomplete_percentage,
        team_health_score: team_health_score
      }
    end

    def calculate_manager_distribution_stats(teammates, teammates_for_joins = nil)
      teammates_for_joins ||= teammates
      
      # Ensure we have an array to work with
      teammates_array = teammates.is_a?(Array) ? teammates : teammates.to_a
      
      # Get organization hierarchy for checking employment tenures
      org_hierarchy = if @organization.company?
        @organization.self_and_descendants
      else
        [@organization, @organization.parent].compact
      end
      
      # Build a set of person IDs who are managers (have active direct reports)
      manager_person_ids = EmploymentTenure.active
                                          .where(company: org_hierarchy)
                                          .where.not(manager_id: nil)
                                          .distinct
                                          .pluck(:manager_id)
                                          .to_set
      
      # Count active managers vs non-managers in the filtered teammates
      active_managers = teammates_array.count { |t| manager_person_ids.include?(t.person_id) }
      non_managers = teammates_array.count - active_managers
      
      # Calculate management levels
      # Build a map of person_id -> their manager's person_id for active employment tenures
      person_to_manager = {}
      EmploymentTenure.active
                      .where(company: org_hierarchy)
                      .joins(:teammate)
                      .pluck('teammates.person_id', :manager_id)
                      .each do |person_id, manager_id|
        person_to_manager[person_id] = manager_id
      end
      
      # Build management levels
      management_levels = {}
      person_to_level = {}
      
      # Find all people in the filtered teammates
      teammate_person_ids = teammates_array.map(&:person_id).to_set
      
      # Level 1: People with no manager (top of hierarchy) who are in our filtered set
      level_1_people = teammate_person_ids.select { |pid| person_to_manager[pid].nil? }
      level_1_people.each { |pid| person_to_level[pid] = 1 }
      management_levels[1] = level_1_people.count
      
      # Continue building levels until no more people can be assigned
      current_level = 1
      max_iterations = 20 # Safety limit to prevent infinite loops
      
      while current_level < max_iterations
        # Find people at current level
        current_level_people = person_to_level.select { |_, level| level == current_level }.keys
        break if current_level_people.empty?
        
        # Find their direct reports who are in our filtered set
        next_level_people = teammate_person_ids.select do |pid|
          person_to_level[pid].nil? && current_level_people.include?(person_to_manager[pid])
        end
        
        break if next_level_people.empty?
        
        # Assign them to the next level
        next_level = current_level + 1
        next_level_people.each { |pid| person_to_level[pid] = next_level }
        management_levels[next_level] = next_level_people.count
        
        current_level = next_level
      end
      
      # Find max level
      max_level = management_levels.keys.max || 0
      
      {
        active_managers: active_managers,
        non_managers: non_managers,
        management_levels: management_levels,
        max_level: max_level,
        total_teammates: teammates_array.count
      }
    end

  def filter_hierarchy_tree(hierarchy_tree, filtered_person_ids)
    # Recursively filter the hierarchy tree to only include nodes matching filters
    hierarchy_tree.map do |node|
      person_id = node[:person]&.id
      next nil unless person_id && filtered_person_ids.include?(person_id)
      
      # Recursively filter children
      filtered_children = filter_hierarchy_tree(node[:children] || [], filtered_person_ids).compact
      
      # Recalculate counts based on filtered children
      direct_reports_count = filtered_children.length
      total_reports_count = direct_reports_count + filtered_children.sum { |child| child[:total_reports_count] || 0 }
      
      {
        person: node[:person],
        position: node[:position],
        employment_tenure: node[:employment_tenure],
        children: filtered_children,
        direct_reports_count: direct_reports_count,
        total_reports_count: total_reports_count
      }
    end.compact
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone_number, :timezone)
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:position_id, :manager_id, :started_at, :employment_change_notes)
  end
end
