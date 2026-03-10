class Organizations::CheckInsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized
  helper_method :can_view_check_ins_health_by_manager?

  def index
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    active_teammates = filtered_teammates_for_check_ins_health.to_a

    # Load cached health data for each teammate
    teammate_ids = active_teammates.map(&:id)
    caches_by_teammate = CheckInHealthCache.where(
      teammate_id: teammate_ids,
      organization_id: @organization.id
    ).index_by(&:teammate_id)

    all_employee_health_data = active_teammates.map do |teammate|
      cache = caches_by_teammate[teammate.id]
      {
        teammate: teammate,
        person: teammate.person,
        cache: cache
      }
    end

    # Spotlight stats from cache (0-4 points per item)
    @spotlight_stats = calculate_spotlight_stats_from_cache(all_employee_health_data)

    # Paginate
    @pagy = Pagy.new(count: all_employee_health_data.count, page: params[:page] || 1, items: 25)
    @employee_health_data = all_employee_health_data[@pagy.offset, @pagy.items]
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = available_check_ins_health_manager_filter_options
  end

  def export
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    active_teammates = filtered_teammates_for_check_ins_health
    csv_content = CheckInsHealthCsvBuilder.new(@organization, active_teammates).call
    filename = "check_ins_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content,
              filename: filename,
              type: 'text/csv',
              disposition: 'attachment'
  end

  def by_manager
    authorize @organization, :check_ins_health?
    unless can_view_check_ins_health_by_manager?
      redirect_to organization_check_ins_health_path(@organization),
                  alert: 'You must be a manager with direct reports to view the By Manager page.'
      return
    end
    company = @organization.root_company || @organization
    manager_teammate_ids = managers_with_direct_reports_for_by_manager(company)
    managers = CompanyTeammate.where(id: manager_teammate_ids).includes(:person).order('people.last_name ASC', 'people.first_name ASC').references(:person)
    @manager_health_rows = managers.map { |manager_teammate| build_by_manager_row(manager_teammate, company) }
  end

  private

  def can_view_check_ins_health_by_manager?
    policy(@organization).manage_employment? || current_company_teammate&.has_direct_reports?
  end

  def managers_with_direct_reports_for_by_manager(company)
    if policy(@organization).manage_employment?
      EmploymentTenure
        .where(company: company, ended_at: nil)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    else
      return [] unless current_company_teammate
      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      EmploymentTenure
        .where(company: company, ended_at: nil, manager_teammate_id: hierarchy_ids)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    end
  end

  def build_by_manager_row(manager_teammate, company)
    direct_report_ids = EmploymentTenure
      .where(company: company, manager_teammate: manager_teammate, ended_at: nil)
      .pluck(:teammate_id)
    caches = CheckInHealthCache.where(
      teammate_id: direct_report_ids,
      organization_id: @organization.id
    ).to_a
    aspiration_counts = aggregate_category_counts(caches.flat_map(&:payload_aspirations))
    assignment_counts = aggregate_category_counts(caches.flat_map(&:payload_assignments))
    position_counts = aggregate_position_counts(caches.map { |c| c.payload_position.presence || {} })
    milestone_total = caches.sum { |c| c.payload_milestones['total_required'].to_i }
    milestone_earned = caches.sum { |c| c.payload_milestones['earned_count'].to_i }
    {
      manager_teammate: manager_teammate,
      aspiration_counts: aspiration_counts,
      assignment_counts: assignment_counts,
      position_counts: position_counts,
      milestone_total_required: milestone_total,
      milestone_earned_count: milestone_earned,
      direct_report_count: direct_report_ids.size
    }
  end

  BAR_CATEGORIES = %w[red orange light_blue light_purple light_green green neon_green].freeze

  def aggregate_category_counts(items)
    return BAR_CATEGORIES.index_with { 0 } if items.empty?
    counts = items.group_by { |i| i['category'].to_s }.transform_values(&:count)
    BAR_CATEGORIES.index_with { |c| counts[c].to_i }
  end

  def aggregate_position_counts(positions)
    return BAR_CATEGORIES.index_with { 0 } if positions.empty?
    counts = positions.group_by { |p| p['category'].to_s.presence || 'red' }.transform_values(&:count)
    BAR_CATEGORIES.index_with { |c| counts[c].to_i }
  end

  def apply_filter_default_if_needed
    return if params[:manager_id].present?
    params[:manager_id] = default_manager_filter_value
  end

  def default_manager_filter_value
    if policy(@organization).manage_employment?
      'everyone'
    elsif current_company_teammate&.has_direct_reports?
      'my_direct_employees'
    elsif current_company_teammate && hierarchy_count_excluding_self > 0
      'my_employees_full_hierarchy'
    else
      'just_me'
    end
  end

  def hierarchy_count_excluding_self
    return 0 unless current_company_teammate && @organization
    ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
    ids.size > 1 ? ids.size - 1 : 0
  end

  def filtered_teammates_for_check_ins_health
    base_scope = CompanyTeammate.for_organization_hierarchy(@organization)
      .where.not(first_employed_at: nil)
      .where(last_terminated_at: nil)
      .includes(:person, :employment_tenures, :organization)
      .joins(:person)
      .order('people.last_name ASC, people.first_name ASC')

    case params[:manager_id].to_s
    when 'everyone'
      return base_scope if policy(@organization).manage_employment?
      viewing_teammate = base_scope.find_by(person: current_person)
      if viewing_teammate
        hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(viewing_teammate, @organization).pluck(:id)
        base_scope.where(id: hierarchy_ids)
      else
        base_scope.none
      end
    when 'my_direct_employees'
      return base_scope.none unless current_company_teammate&.has_direct_reports?
      direct_report_ids = EmploymentTenure
        .where(company: @organization, manager_teammate: current_company_teammate, ended_at: nil)
        .pluck(:teammate_id)
      base_scope.where(id: direct_report_ids)
    when 'my_employees_full_hierarchy'
      return base_scope.none unless current_company_teammate
      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      base_scope.where(id: hierarchy_ids)
    when 'just_me'
      return base_scope.none unless current_company_teammate
      base_scope.where(id: current_company_teammate.id)
    else
      # CompanyTeammate_<id> for a specific manager
      if params[:manager_id].to_s =~ /\ACompanyTeammate_(\d+)\z/
        manager_id = Regexp.last_match(1).to_i
        return base_scope.none unless manager_viewable?(manager_id)
        direct_report_ids = EmploymentTenure
          .where(company: @organization, manager_teammate_id: manager_id, ended_at: nil)
          .pluck(:teammate_id)
        base_scope.where(id: direct_report_ids)
      else
        # Unrecognized value: fall back to default filter
        params[:manager_id] = default_manager_filter_value
        filtered_teammates_for_check_ins_health
      end
    end
  end

  def manager_viewable?(manager_id)
    return true if policy(@organization).manage_employment?
    return false unless current_company_teammate
    hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
    hierarchy_ids.include?(manager_id)
  end

  def available_check_ins_health_manager_filter_options
    company = @organization.root_company || @organization
    options = []
    options << ['Everyone', 'everyone'] if policy(@organization).manage_employment?
    options << ['My Direct Employees', 'my_direct_employees'] if current_company_teammate&.has_direct_reports?
    options << ['My Employees (full hierarchy)', 'my_employees_full_hierarchy'] if current_company_teammate && hierarchy_count_excluding_self > 0
    options << ['Just Me', 'just_me']
    manager_opts = visible_managers_for_check_ins_health(company)
    options.concat(manager_opts)
    options
  end

  def visible_managers_for_check_ins_health(company)
    if policy(@organization).manage_employment?
      manager_teammate_ids = EmploymentTenure
        .where(company: company, ended_at: nil)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    else
      return [] unless current_company_teammate
      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      manager_teammate_ids = EmploymentTenure
        .where(company: company, ended_at: nil, manager_teammate_id: hierarchy_ids)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    end
    teammates = CompanyTeammate.where(id: manager_teammate_ids).joins(:person).order('people.last_name ASC', 'people.first_name ASC')
    teammates.map { |t| ["Manager: #{t.person&.display_name}", "CompanyTeammate_#{t.id}"] }.reject { |pair| pair[0].blank? }
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end

  def calculate_spotlight_stats_from_cache(employee_health_data)
    total_employees = employee_health_data.count
    all_healthy = 0
    needing_attention = 0
    total_points = 0.0
    max_points = 0.0

    employee_health_data.each do |data|
      cache = data[:cache]
      unless cache
        needing_attention += 1
        next
      end
      points = cache.completion_points
      pos_pts = points[:position].to_f
      assign_pts = points[:assignments].to_f
      aspir_pts = points[:aspirations].to_f
      mile_pts = points[:milestones].to_f
      pos_max = 4.0
      assign_max = (cache.payload_assignments.size * 4).to_f
      assign_max = 4.0 if cache.payload_assignments.empty?
      aspir_max = (cache.payload_aspirations.size * 4).to_f
      aspir_max = 4.0 if cache.payload_aspirations.empty?
      mile_max = 4.0
      total_max = pos_max + assign_max + aspir_max + mile_max
      total_points += pos_pts + assign_pts + aspir_pts + mile_pts
      max_points += total_max
      if pos_pts >= 4 && assign_pts >= assign_max && aspir_pts >= aspir_max && mile_pts >= 4
        all_healthy += 1
      elsif pos_pts < 2 || assign_pts < assign_max * 0.5 || aspir_pts < aspir_max * 0.5 || mile_pts < 2
        needing_attention += 1
      end
    end

    completion_rate = max_points.positive? ? (total_points / max_points * 100).round(1) : 0

    {
      total_employees: total_employees,
      all_healthy: all_healthy,
      needing_attention: needing_attention,
      completion_rate: completion_rate
    }
  end
end
