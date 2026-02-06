class CompanyTeammatesQuery
  attr_reader :organization, :params, :current_person

  def initialize(organization, params = {}, current_person: nil)
    @organization = organization
    @params = params
    @current_person = current_person
  end

  def call
    teammates = base_scope
    teammates = filter_by_organization(teammates)
    teammates = filter_by_permissions(teammates)
    teammates = filter_by_manager_relationship(teammates)
    teammates = filter_by_department(teammates)
    teammates = apply_sort(teammates)
    # Ensure distinct to avoid duplicates from joins (e.g., manager filter)
    # Note: Status filtering is complex and requires Array conversion
    # This should be applied after pagination in the controller
    teammates.distinct
  end
  
  def call_with_status_filter
    teammates = call
    filter_by_status(teammates)
  end

  def current_filters
    filters = {}
    # Expand status shortcuts to granular statuses for checkbox display
    if params[:status].present?
      statuses = Array(params[:status])
      expanded_statuses = expand_status_shortcuts(statuses)
      filters[:status] = expanded_statuses.uniq
    end
    filters[:organization_id] = params[:organization_id] if params[:organization_id].present?
    filters[:permission] = params[:permission] if params[:permission].present?
    # Handle both single manager_teammate_id and manager_teammate_id[] array
    if params[:manager_teammate_id].present?
      manager_teammate_ids = Array(params[:manager_teammate_id])
      filters[:manager_teammate_id] = manager_teammate_ids.map(&:to_s)
    end
    # Handle department_id[] array
    if params[:department_id].present?
      department_ids = Array(params[:department_id])
      filters[:department_id] = department_ids.map(&:to_s)
    end
    filters
  end

  def current_sort
    params[:sort] || 'name_asc'
  end

  def current_view
    # Prioritize display over view, but fall back if display is empty
    return params[:display] unless params[:display].blank?
    return params[:view] unless params[:view].blank?
    'list'
  end

  def current_spotlight
    params[:spotlight] || 'teammates_overview'
  end

  def has_active_filters?
    # Check if any filter has a value (even empty string counts as an active filter for UI state)
    current_filters.any?
  end

  def filter_by_status(teammates)
    return teammates unless params[:status].present?

    statuses = Array(params[:status])
    return teammates if statuses.empty?

    # Separate shortcuts from granular statuses
    shortcuts = statuses.select { |s| ['active', 'terminated', 'all_employed'].include?(s.to_s) }
    granular_statuses = statuses - shortcuts

    # Apply database-level filters for shortcuts (more efficient)
    if shortcuts.include?('active')
      teammates = teammates.where.not(first_employed_at: nil).where(last_terminated_at: nil)
    end

    if shortcuts.include?('all_employed')
      teammates = teammates.where.not(first_employed_at: nil)
    end

    if shortcuts.include?('terminated')
      teammates = teammates.where.not(last_terminated_at: nil)
    end

    # If we have granular statuses, also filter by those using TeammateStatus
    # (These might be redundant if shortcuts cover them, but handle for completeness)
    if granular_statuses.any?
      teammates.select do |teammate|
        status = TeammateStatus.new(teammate).status
        granular_statuses.include?(status.to_s)
      end
    else
      teammates
    end
  end

  private

  def expand_status_shortcuts(statuses)
    expanded = []
    statuses.each do |status|
      case status.to_s
      when 'active'
        expanded.concat(['assigned_employee', 'unassigned_employee'])
      when 'all_employed'
        expanded.concat(['assigned_employee', 'unassigned_employee', 'terminated'])
      when 'terminated'
        expanded << 'terminated'
      else
        # Keep granular statuses as-is
        expanded << status.to_s
      end
    end
    expanded.uniq
  end

  def base_scope
    CompanyTeammate.for_organization_hierarchy(organization)
                   .includes(:person, :employment_tenures, :organization)
  end

  def filter_by_organization(teammates)
    return teammates unless params[:organization_id].present?

    org_id = params[:organization_id].to_i
    organization = Organization.find(org_id)
    teammates.where(organization: organization.self_and_descendants)
  end

  def filter_by_permissions(teammates)
    return teammates unless params[:permission].present?

    permissions = Array(params[:permission])
    return teammates if permissions.empty?

    filtered_teammates = teammates

    permissions.each do |permission|
      case permission
      when 'employment_mgmt'
        filtered_teammates = filtered_teammates.where(can_manage_employment: true)
      when 'employment_create'
        filtered_teammates = filtered_teammates.where(can_create_employment: true)
      when 'maap_mgmt'
        filtered_teammates = filtered_teammates.where(can_manage_maap: true)
      when 'customize_company'
        filtered_teammates = filtered_teammates.where(can_customize_company: true)
      when 'highlights_rewards'
        filtered_teammates = filtered_teammates.where(can_manage_highlights_rewards: true)
      end
    end

    filtered_teammates
  end

  def filter_by_manager_relationship(teammates)
    return teammates unless params[:manager_teammate_id].present?

    manager_teammate_ids = Array(params[:manager_teammate_id]).map(&:to_i).reject(&:zero?)
    return teammates if manager_teammate_ids.empty?

    # Filter to only direct reports based on active employment tenure manager relationships
    teammates.joins(:employment_tenures)
             .where(employment_tenures: { manager_teammate_id: manager_teammate_ids, ended_at: nil })
             .distinct
  end

  def filter_by_department(teammates)
    return teammates unless params[:department_id].present?

    department_ids = Array(params[:department_id]).map(&:to_i).reject(&:zero?)
    return teammates if department_ids.empty?

    # Get all department organizations and their descendants
    department_orgs = Organization.where(id: department_ids)
    all_org_ids = department_orgs.flat_map { |dept| dept.self_and_descendants.map(&:id) }.uniq

    # Filter teammates where organization is in the department hierarchy
    teammates.where(organization_id: all_org_ids)
  end

  def apply_sort(teammates)
    case params[:sort]
    when 'name_desc'
      teammates.joins(:person).order('people.last_name DESC, people.first_name DESC')
    when 'status'
      # Sort by status in meaningful order: assigned_employee, unassigned_employee, huddler, follower, terminated
      teammates.joins(:person).order(
        Arel.sql("CASE 
          WHEN last_terminated_at IS NOT NULL THEN 5
          WHEN first_employed_at IS NOT NULL AND last_terminated_at IS NULL THEN 1
          WHEN first_employed_at IS NULL AND last_terminated_at IS NULL THEN 3
          ELSE 4
        END"),
        'people.last_name ASC, people.first_name ASC'
      )
    when 'organization'
      teammates.joins(:organization).order('organizations.name ASC, people.last_name ASC, people.first_name ASC')
    when 'employment_date'
      teammates.joins(:person).order('first_employed_at DESC NULLS LAST, people.last_name ASC, people.first_name ASC')
    else # 'name_asc' or default
      teammates.joins(:person).order('people.last_name ASC, people.first_name ASC')
    end
  end
end
