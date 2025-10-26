class TeammatesQuery
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
    teammates = apply_sort(teammates)
    # Note: Status filtering is complex and requires Array conversion
    # This should be applied after pagination in the controller
    teammates
  end
  
  def call_with_status_filter
    teammates = call
    filter_by_status(teammates)
  end

  def current_filters
    filters = {}
    filters[:status] = params[:status] if params[:status].present?
    filters[:organization_id] = params[:organization_id] if params[:organization_id].present?
    filters[:permission] = params[:permission] if params[:permission].present?
    filters[:manager_filter] = params[:manager_filter] if params[:manager_filter].present?
    filters
  end

  def current_sort
    params[:sort] || 'name_asc'
  end

  def current_view
    params[:view] || params[:display] || 'table'
  end

  def has_active_filters?
    current_filters.any?
  end

  def filter_by_status(teammates)
    return teammates unless params[:status].present?

    statuses = Array(params[:status])
    return teammates if statuses.empty?

    # Filter teammates based on their status using TeammateStatus
    teammates.select do |teammate|
      status = TeammateStatus.new(teammate).status
      statuses.include?(status.to_s)
    end
  end

  private

  def base_scope
    Teammate.for_organization_hierarchy(organization)
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
      end
    end

    filtered_teammates
  end

  def filter_by_manager_relationship(teammates)
    return teammates unless params[:manager_filter] == 'direct_reports'
    return teammates unless current_person

    # Filter to only direct reports based on active employment tenure manager relationships
    teammates.joins(:employment_tenures)
             .where(employment_tenures: { manager: current_person, ended_at: nil })
             .distinct
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
