class Organizations::EmployeesController < Organizations::OrganizationNamespaceBaseController
  include TeammateHelper
  include Organizations::AssignsViewableTeammates

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
    
    # Set default view to managers_view when manager_teammate_id is present and no view is explicitly set
    if params[:manager_teammate_id].present? && params[:view].blank? && params[:display].blank?
      params[:view] = 'managers_view'
    end
    
    # Determine spotlight type
    @current_spotlight = determine_spotlight
    
    # Use CompanyTeammatesQuery for filtering and sorting
    query = CompanyTeammatesQuery.new(@organization, params, current_person: current_person)
    
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
                                                       .joins(:company_teammate)
                                                       .where(company_id: org_ids)
                                                       .where(teammates: { organization_id: org_ids })
                                                       .select('DISTINCT teammates.id')
      
      # Start with unassigned teammates query
      unassigned_base = CompanyTeammate.where(organization_id: org_ids)
                                .where.not(id: teammates_with_active_tenures)
                                .where.not(first_employed_at: nil)
                                .where(last_terminated_at: nil)
                                .includes(:person)
                                .joins(:person)
      
      # Apply the same filters from CompanyTeammatesQuery manually (since methods are private)
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
      if params[:manager_teammate_id].present?
        manager_teammate_ids = Array(params[:manager_teammate_id]).map(&:to_i).reject(&:zero?)
        if manager_teammate_ids.any?
          unassigned_base = unassigned_base.joins(:employment_tenures)
                                           .where(employment_tenures: { manager_teammate_id: manager_teammate_ids, ended_at: nil })
                                           .distinct
        end
      end
      
      # Filter by department
      if params[:department_id].present?
        department_ids = Array(params[:department_id]).map(&:to_i).reject(&:zero?)
        if department_ids.any?
          department_orgs = Organization.where(id: department_ids)
          all_org_ids = department_orgs.flat_map { |dept| dept.self_and_descendants.map(&:id) }.uniq
          unassigned_base = unassigned_base.where(organization_id: all_org_ids)
        end
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
      # Preload check-in health caches for manager lite (90-day completion % next to check-in button)
      if @filtered_and_paginated_teammates.any?
        teammate_ids = @filtered_and_paginated_teammates.map(&:id)
        @engagement_health_by_teammate_id = EngagementHealth::ClarityMetrics.records_by_teammate_id(
          organization: @organization,
          teammate_ids: teammate_ids
        )
      else
        @engagement_health_by_teammate_id = {}
      end

      @managers_view_row_data_by_teammate_id =
        if query.current_view == 'managers_view' && @filtered_and_paginated_teammates.any?
          ManagersViewCardDataService.load(
            teammates: @filtered_and_paginated_teammates,
            organization: @organization,
            viewing_teammate: current_company_teammate
          )
        else
          {}
        end

      if query.current_view == 'start_page'
        load_start_page_display_data(@filtered_and_paginated_teammates)
      else
        @start_page_by_teammate_id = {}
        @start_page_summary_by_teammate_id = {}
        @can_edit_start_page_by_teammate_id = {}
      end
      
      # For spotlight calculations, we need the original relation (before status filtering) for joins
      # but use filtered_teammates for counts. Pass both to calculate_spotlight_stats.
      filtered_teammates_for_joins = filtered_teammates
      
      # Eager load associations on filtered_teammates_for_joins as needed (for spotlight calculations)
      if @current_spotlight == 'employee_locations'
        filtered_teammates_for_joins = filtered_teammates_for_joins.includes(person: :addresses)
      end
      
      # Calculate spotlight statistics from filtered_teammates (honors filters, not pagination)
      @spotlight_stats = calculate_spotlight_stats(@filtered_teammates, @current_spotlight, filtered_teammates_for_joins)
    end
    
    # Store current filter/sort state for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @has_active_filters = query.has_active_filters?
  end

  def update_start_page
    authorize @organization, :show?
    teammate = @organization.teammates.find(params[:id])

    unless allow_start_page_edit_for?(teammate)
      redirect_back fallback_location: organization_employees_path(@organization), alert: 'You do not have permission to update this teammate start page.'
      return
    end

    allowed = helpers.start_page_options_for_select(@organization, teammate).map { |pair| pair.last.to_s }
    value = params[:start_page].to_s
    unless allowed.include?(value)
      redirect_back fallback_location: organization_employees_path(@organization, view: 'start_page'), alert: 'Invalid start page.'
      return
    end

    key = helpers.start_page_preference_key(@organization)
    UserPreference.for_person(teammate.person).update_preference(key, value)
    redirect_back fallback_location: organization_employees_path(@organization, view: 'start_page'), notice: 'Start page updated.'
  end

  def copy_start_page_configuration
    authorize @organization, :show?
    source_teammate = @organization.teammates.find(params[:id])

    source_pref = UserPreference.for_person(source_teammate.person).preferences[StartHereDashboardService::PREFERENCE_KEY]
    unless source_pref.is_a?(Hash) && source_pref.present?
      redirect_back fallback_location: organization_employees_path(@organization, view: 'start_page'), alert: 'No Start Here configuration to copy.'
      return
    end

    copied_value = source_pref.deep_dup
    UserPreference.for_person(current_person).update_preference(StartHereDashboardService::PREFERENCE_KEY, copied_value)
    redirect_back fallback_location: organization_employees_path(@organization, view: 'start_page'), notice: 'Start Here configuration copied.'
  end

  def customize_view
    # Authorization: require ability to view organization
    authorize @organization, :show?
    
    # Load current state from params or defaults
    query = CompanyTeammatesQuery.new(@organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = determine_spotlight
    @has_active_filters = query.has_active_filters?
    @active_managers = active_managers_for_organization
    @active_departments = active_departments_for_organization
    
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
    
    # Build redirect URL with view customization params
    if params[:preset].present?
      # When preset is selected, only include preset-defined params
      preset_params = preset_to_params(params[:preset])
      redirect_params = {}
      
      if preset_params
        # Use preset params directly - Rails path helpers handle arrays automatically
        redirect_params = preset_params.dup
      end
    else
      # When no preset, include all params except Rails internal ones
      redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h.compact
    end
    
    redirect_to organization_employees_path(@organization, redirect_params), notice: 'View updated successfully.'
  end

  def new_employee
    # For creating a new person and employment simultaneously
    authorize @organization, :manage_employment?
    @person = Person.new
    @employment_tenure = EmploymentTenure.new
    load_new_employee_form_supporting_data
  end

  def create_employee
    # For creating a new person and employment simultaneously
    authorize @organization, :manage_employment?
    assign_new_employee_form_objects_from_params

    if (conflict = in_organization_email_conflict)
      render_employee_email_conflict(**conflict)
      return
    end

    persist_new_employee!
  rescue ActiveRecord::RecordInvalid
    @person = build_person_from_params if @person.nil?
    @employment_tenure = build_employment_tenure_from_params if @employment_tenure.nil?
    load_new_employee_form_supporting_data
    render :new_employee, status: :unprocessable_entity
  rescue => e
    assign_new_employee_form_objects_from_params if params[:person].present?
    @person ||= Person.new
    @employment_tenure ||= EmploymentTenure.new
    load_new_employee_form_supporting_data
    @error_message = "An error occurred: #{e.message}"
    render :new_employee, status: :unprocessable_entity
  end

  def resolve_employee_email_conflict
    authorize @organization, :manage_employment?
    assign_new_employee_form_objects_from_params

    @existing_person = Person.find(params.require(:existing_person_id))
    @existing_teammate = @existing_person.teammates.find_by(organization: @organization)
    unless @existing_teammate
      @error_message = 'That person is no longer a teammate in this organization. You can create the employee now.'
      load_new_employee_form_supporting_data
      render :new_employee, status: :unprocessable_entity
      return
    end

    case params[:resolution]
    when 'rehire'
      redirect_to organization_company_teammate_path(@organization, @existing_teammate)
    when 'change_new_email'
      load_new_employee_form_supporting_data
      render :new_employee
    when 'archive_old_email'
      ActiveRecord::Base.transaction do
        @existing_person.update!(email: @existing_person.archived_email_replacement)
        persist_new_employee!(force_new_person: true)
      end
    else
      render_employee_email_conflict(
        existing_person: @existing_person,
        existing_teammate: @existing_teammate
      )
    end
  rescue ActiveRecord::RecordInvalid
    @person = build_person_from_params if @person.nil?
    @employment_tenure = build_employment_tenure_from_params if @employment_tenure.nil?
    load_new_employee_form_supporting_data
    render :new_employee, status: :unprocessable_entity
  rescue => e
    assign_new_employee_form_objects_from_params if params[:person].present?
    @person ||= Person.new
    @employment_tenure ||= EmploymentTenure.new
    load_new_employee_form_supporting_data
    @error_message = "An error occurred: #{e.message}"
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

    assign_viewable_teammates_context!(selected_teammate: @teammate)

    # Get MAAP snapshots for this teammate within this organization
    @maap_snapshots = MaapSnapshot.for_employee_teammate(@teammate)
                                  .for_company(@organization)
                                  .recent
                                  .includes(:creator_company_teammate)
    
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
    
    teammate = @person.teammates.find_by(organization: @organization)
    # Only allow employees to acknowledge their own snapshots
    unless current_person == @person
      redirect_to audit_organization_employee_path(@organization, teammate), 
                  alert: 'You can only acknowledge your own check-ins.'
      return
    end
    
    # Get selected snapshot IDs
    snapshot_ids = params[:snapshot_ids] || []
    
    if snapshot_ids.empty?
      redirect_to audit_organization_employee_path(@organization, teammate), 
                  alert: 'Please select at least one check-in to acknowledge.'
      return
    end
    
    # Find and acknowledge the snapshots
    # Get the teammate for the person in this organization
    teammate = @person.teammates.find_by(organization: @organization)
    
    if teammate
      snapshots = MaapSnapshot.where(id: snapshot_ids, employee_company_teammate: teammate).where.not(effective_date: nil)
    else
      redirect_to audit_organization_employee_path(@organization, teammate), 
                  alert: 'Unable to find teammate record.'
      return
    end
    
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

      EngagementHealth.schedule_refresh_for(teammate.id) if teammate && acknowledged_count.positive?
    
    redirect_to audit_organization_employee_path(@organization, teammate), 
                notice: "Successfully acknowledged #{acknowledged_count} check-in#{'s' if acknowledged_count != 1}."
  end
  
  private

  def load_start_page_display_data(teammates)
    key = helpers.start_page_preference_key(@organization)
    @start_page_by_teammate_id = {}
    @start_page_summary_by_teammate_id = {}
    @can_edit_start_page_by_teammate_id = {}

    teammates.each do |teammate|
      pref = UserPreference.for_person(teammate.person)
      start_page_value = pref.preference(key).presence || 'about_me'
      @start_page_by_teammate_id[teammate.id] = start_page_value
      @start_page_summary_by_teammate_id[teammate.id] = helpers.start_page_dashboard_summary_for_person(@organization, teammate, teammate.person)
      @can_edit_start_page_by_teammate_id[teammate.id] = allow_start_page_edit_for?(teammate)
    end
  end

  def allow_start_page_edit_for?(teammate)
    return false unless current_company_teammate && teammate
    return true if policy(@organization).manage_employment?
    return true if current_company_teammate == teammate

    current_company_teammate.in_managerial_hierarchy_of?(teammate)
  end

  def active_managers_for_organization
    # Get active managers (for filtering, lenient mode - don't require them to be active teammates)
    ActiveManagersQuery.new(company: @organization, require_active_teammate: false).call
  end

  def load_manager_data
    company = @organization.root_company || @organization
    
    # Load distinct active managers (CompanyTeammates who are managers in active employment tenures)
    active_manager_teammates = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
    @managers = active_manager_teammates
    
    # Load all active employees (for manager selection)
    # Organizations no longer have parent hierarchy - use the company directly
    org_hierarchy = [company]
    
    # Get all active employees (CompanyTeammates with active employment tenures in the organization hierarchy)
    all_active_teammate_ids = EmploymentTenure.active
                                              .joins(:company_teammate)
                                              .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                              .distinct
                                              .pluck('teammates.id')
    
    # Exclude managers (to prevent duplicates)
    manager_teammate_ids = @managers.map { |m| m.is_a?(CompanyTeammate) ? m.id : CompanyTeammate.find_by(organization: company, person: m)&.id }.compact
    non_manager_teammate_ids = all_active_teammate_ids - manager_teammate_ids
    
    # Get CompanyTeammate objects for non-manager employees, ordered by person's last_name, first_name
    @all_employees = CompanyTeammate.where(id: non_manager_teammate_ids)
                                    .joins(:person)
                                    .order('people.last_name, people.first_name')
  end

  def active_departments_for_organization
    # Get active departments for the company (departments are now a separate model)
    company = @organization.root_company || @organization
    Department.where(company: company).active.order(:name)
  end

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
          manager_teammate_id: current_company_teammate&.id
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
      # If spotlight param is set, use it (legacy check_ins_health spotlight removed)
      if params[:spotlight].present?
        return 'teammates_overview' if params[:spotlight] == 'check_ins_health'

        return params[:spotlight]
      end
      
      # Auto-select manager_lite if manager filter is active
      return 'manager_lite' if params[:manager_teammate_id].present?
      
      # Default to teammates_overview (matches CompanyTeammatesQuery default)
      'teammates_overview'
    end

    def eager_load_check_in_data(teammates)
      # Convert array back to ActiveRecord relation for eager loading if needed
      if teammates.is_a?(Array)
        teammate_ids = teammates.map(&:id)
        teammates_relation = CompanyTeammate.where(id: teammate_ids)
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
      when 'teammate_tenures'
        calculate_tenure_stats(teammates)
      when 'employee_locations'
        calculate_location_stats(teammates)
      when 'manager_overview'
        calculate_manager_overview_stats(teammates, teammates_for_joins)
      when 'manager_distribution'
        calculate_manager_distribution_stats(teammates, teammates_for_joins)
      when 'manager_lite'
        calculate_manager_lite_stats(teammates, teammates_for_joins)
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
        teammates_relation = CompanyTeammate.where(id: teammate_ids)
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
        teammates_relation = CompanyTeammate.where(id: teammate_ids)
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
      
      # Build a set of person IDs who are managers (have active direct reports)
      # Use lenient mode (don't require active teammates) for stats calculation
      manager_person_ids = ActiveManagersQuery.new(company: @organization, require_active_teammate: false).manager_ids.to_set
      
      # Count active managers vs non-managers in the filtered teammates
      active_managers = teammates_array.count { |t| manager_person_ids.include?(t.person_id) }
      non_managers = teammates_array.count - active_managers
      
      # Calculate management levels
      # Build a map of person_id -> their manager's person_id for active employment tenures
      # Organizations no longer have parent hierarchy - use the organization directly
      org_hierarchy = [@organization]
      
      person_to_manager = {}
      EmploymentTenure.active
                      .where(company: org_hierarchy)
                      .joins(:company_teammate)
                      .joins('LEFT JOIN teammates AS manager_teammates ON employment_tenures.manager_teammate_id = manager_teammates.id')
                      .pluck('teammates.person_id', 'manager_teammates.person_id')
                      .each do |person_id, manager_person_id|
        person_to_manager[person_id] = manager_person_id
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

    def calculate_manager_lite_stats(teammates, teammates_for_joins = nil)
      teammates_for_joins ||= teammates
      
      # Ensure we have an ActiveRecord relation for proper joins
      if teammates_for_joins.is_a?(Array)
        teammate_ids = teammates_for_joins.map(&:id)
        teammates_relation = CompanyTeammate.where(id: teammate_ids)
      else
        teammates_relation = teammates_for_joins
      end
      
      # Total teammates
      total_teammates = teammates.count
      
      # Teammates with finalized position check-in in last 90 days
      position_check_in_cutoff = 90.days.ago
      teammates_with_position_check_in = teammates_relation
        .joins(:position_check_ins)
        .where(position_check_ins: { official_check_in_completed_at: position_check_in_cutoff.. })
        .unscope(:order)
        .select('teammates.id')
        .distinct
        .count
      
      # Teammates with finalized assignment check-in in last 90 days
      teammates_with_assignment_check_in = teammates_relation
        .joins(:assignment_check_ins)
        .where(assignment_check_ins: { official_check_in_completed_at: position_check_in_cutoff.. })
        .unscope(:order)
        .select('teammates.id')
        .distinct
        .count
      
      # Teammates with finalized aspiration check-in in last 90 days
      teammates_with_aspiration_check_in = teammates_relation
        .joins(:aspiration_check_ins)
        .where(aspiration_check_ins: { official_check_in_completed_at: position_check_in_cutoff.. })
        .unscope(:order)
        .select('teammates.id')
        .distinct
        .count
      
      # Teammates with an active goal
      teammate_ids = teammates_relation.unscope(:order).select('teammates.id').distinct.pluck(:id)
      teammates_with_active_goal = Goal
        .where(owner_type: 'CompanyTeammate', owner_id: teammate_ids, company: @organization)
        .active
        .select(:owner_id)
        .distinct
        .count
      
      # Teammates who have given a published observation in last 30 days
      observation_cutoff = 30.days.ago
      person_ids = teammates_relation.unscope(:order).select('teammates.person_id').distinct.pluck(:person_id)
      teammates_given_observation = Observation
        .where(observer_id: person_ids, company: @organization, published_at: observation_cutoff.., deleted_at: nil)
        .where.not(privacy_level: 'observer_only')
        .select(:observer_id)
        .distinct
        .count
      
      # Teammates who have received a published observation in last 30 days
      teammates_received_observation = Observation
        .joins(:observees)
        .where(observees: { teammate_id: teammate_ids }, company: @organization, published_at: observation_cutoff.., deleted_at: nil)
        .where.not(privacy_level: 'observer_only')
        .select('observees.teammate_id')
        .distinct
        .count
      
      {
        total_teammates: total_teammates,
        teammates_with_position_check_in: teammates_with_position_check_in,
        teammates_with_assignment_check_in: teammates_with_assignment_check_in,
        teammates_with_aspiration_check_in: teammates_with_aspiration_check_in,
        teammates_with_active_goal: teammates_with_active_goal,
        teammates_given_observation: teammates_given_observation,
        teammates_received_observation: teammates_received_observation
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

  def assign_new_employee_form_objects_from_params
    @person = build_person_from_params
    @employment_tenure = build_employment_tenure_from_params
  end

  def build_person_from_params
    person_attrs = person_params.to_h
    @phone_number = person_attrs.delete('phone_number')
    person_attrs['unique_textable_phone_number'] = @phone_number if @phone_number.present?
    Person.new(person_attrs)
  end

  def build_employment_tenure_from_params
    EmploymentTenure.new(employment_tenure_params)
  end

  def load_new_employee_form_supporting_data
    @positions = @organization.positions.unarchived.includes(:title, :position_level)
                              .joins(:title)
                              .order('titles.external_title')
    load_manager_data
  end

  def in_organization_email_conflict
    email = @person.email
    return nil if email.blank?

    existing_person = Person.find_by_email_insensitive(email)
    return nil unless existing_person

    existing_teammate = existing_person.teammates.find_by(organization: @organization)
    return nil unless existing_teammate

    { existing_person: existing_person, existing_teammate: existing_teammate }
  end

  def render_employee_email_conflict(existing_person:, existing_teammate:)
    @existing_person = existing_person
    @existing_teammate = existing_teammate
    @archived_email = existing_person.archived_email_replacement
    load_new_employee_form_supporting_data
    render :email_conflict, status: :conflict
  end

  def persist_new_employee!(force_new_person: false)
    ActiveRecord::Base.transaction do
      person_attrs = person_params.to_h
      if person_attrs.key?('phone_number')
        person_attrs['unique_textable_phone_number'] = person_attrs.delete('phone_number')
      end

      unless force_new_person
        @person = Person.find_by_email_insensitive(person_attrs['email'])
      end

      unless @person&.persisted?
        @person = Person.new(person_attrs)
        @person.save!
      end

      employment_params = employment_tenure_params.to_h
      start_date = employment_params['started_at']

      teammate = @person.teammates.find_or_create_by!(organization: @organization) do |t|
        t.first_employed_at = start_date if start_date.present?
      end
      teammate.update!(first_employed_at: start_date) if start_date.present? && teammate.first_employed_at != start_date

      @employment_tenure = teammate.employment_tenures.build(employment_tenure_params)
      @employment_tenure.company = @organization
      @employment_tenure.company_teammate = teammate
      @employment_tenure.save!

      ObservableMoments::CreateNewHireMomentService.call(
        employment_tenure: @employment_tenure,
        created_by: current_person
      )

      teammate = @person.teammates.find_by(organization: @organization)
      EngagementHealth.schedule_refresh_for(teammate.id) if teammate
      redirect_to organization_company_teammate_path(@organization, teammate), notice: 'Employee was successfully created.'
    end
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone_number, :timezone)
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:position_id, :manager_teammate_id, :started_at, :employment_change_notes)
  end
end
