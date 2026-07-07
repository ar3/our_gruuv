class Organizations::CheckInsHealthController < Organizations::OrganizationNamespaceBaseController
  include Organizations::CheckInsHealthTeammateFiltering

  before_action :require_authentication
  after_action :verify_authorized
  helper_method :can_view_check_ins_health_by_manager?

  def index
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    page = params[:page] || 1
    data = check_ins_health_spotlight_service.paginated_index_data(
      params[:manager_id],
      page: page,
      items: 25
    )
    @spotlight_stats = data.fetch(:spotlight_stats)
    @pagy = Pagy.new(count: data.fetch(:total_count), page: page, items: 25)
    @employee_health_data = data.fetch(:rows)
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = check_ins_health_spotlight_service.available_manager_filter_options
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

  def export_employee_summary
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    active_teammates = filtered_teammates_for_check_ins_health
    csv_content = CheckInsHealthEmployeeSummaryCsvBuilder.new(@organization, active_teammates).call
    filename = "employee_check_in_summary_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
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
    @sort_by = apply_by_manager_sort
  end

  def refresh
    authorize @organization, :check_ins_health?

    teammate = @organization.teammates.find_by(id: params[:teammate_id])
    unless teammate
      redirect_back fallback_location: organization_check_ins_health_path(@organization), alert: 'Could not refresh: teammate not found.'
      return
    end

    EngagementHealth.schedule_refresh_for(teammate.id)
    redirect_back fallback_location: organization_check_ins_health_path(@organization), notice: "Gruuv Health refresh queued for #{teammate.person.display_name}."
  end

  def refresh_all
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed

    teammate_ids = check_ins_health_spotlight_service.filtered_teammate_ids(params[:manager_id])
    teammate_ids.each do |teammate_id|
      EngagementHealth.schedule_refresh_for(teammate_id)
    end

    redirect_to organization_check_ins_health_path(@organization, manager_id: params[:manager_id]),
                notice: "Gruuv Health refresh queued for #{teammate_ids.size} teammate#{'s' if teammate_ids.size != 1}."
  end

  private

  def apply_by_manager_sort
    sort = params[:sort].to_s
    sort = 'name' unless %w[name completion_rate].include?(sort)
    if sort == 'completion_rate'
      @manager_health_rows.sort_by! { |row| -row[:completion_rate].to_f }
    end
    sort
  end

  def can_view_check_ins_health_by_manager?
    policy(@organization).manage_employment? || current_company_teammate&.has_direct_reports?
  end

  def check_ins_health_spotlight_service
    @check_ins_health_spotlight_service ||= CheckInsHealthSpotlightService.new(
      organization: @organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: policy(@organization).manage_employment?
    )
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
    records_by_teammate_id = EngagementHealth::ClarityMetrics.records_by_teammate_id(
      organization: @organization,
      teammate_ids: direct_report_ids
    )
    all_items = direct_report_ids.flat_map do |teammate_id|
      EngagementHealth::ClarityMetrics.clarity_items(records_by_teammate_id[teammate_id] || [])
    end
    aspiration_items = all_items.select { |item| item.entity_type == "Aspiration" }
    assignment_items = all_items.select { |item| item.entity_type == "Assignment" }
    position_items = all_items.select { |item| item.entity_type == "Position" }
    {
      manager_teammate: manager_teammate,
      aspiration_status_counts: EngagementHealth::ClarityMetrics.status_counts_for_items(aspiration_items),
      assignment_status_counts: EngagementHealth::ClarityMetrics.status_counts_for_items(assignment_items),
      position_status_counts: EngagementHealth::ClarityMetrics.status_counts_for_items(position_items),
      direct_report_count: direct_report_ids.size,
      completion_rate: EngagementHealth::ClarityMetrics.average_healthy_percentage_for_teammates(
        records_by_teammate_id,
        direct_report_ids
      )
    }
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end
end
