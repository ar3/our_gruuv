class Organizations::CheckInsHealthController < Organizations::OrganizationNamespaceBaseController
  include CheckInHealthCompletionRate
  include Organizations::CheckInsHealthTeammateFiltering

  before_action :require_authentication
  after_action :verify_authorized
  helper_method :can_view_check_ins_health_by_manager?

  def index
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    data = check_ins_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])
    all_employee_health_data = data.fetch(:rows)
    @spotlight_stats = data.fetch(:spotlight_stats)

    # Paginate
    @pagy = Pagy.new(count: all_employee_health_data.count, page: params[:page] || 1, items: 25)
    @employee_health_data = all_employee_health_data[@pagy.offset, @pagy.items]
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

    CheckInHealthCacheRefreshJob.perform_later(teammate.id)
    redirect_back fallback_location: organization_check_ins_health_path(@organization), notice: "Refresh queued for #{teammate.person.display_name}."
  end

  def refresh_all
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed

    teammate_ids = check_ins_health_spotlight_service.filtered_teammates(params[:manager_id]).pluck(:id)
    teammate_ids.each { |teammate_id| CheckInHealthCacheRefreshJob.perform_later(teammate_id) }

    redirect_to organization_check_ins_health_path(@organization, manager_id: params[:manager_id]),
                notice: "Refresh queued for #{teammate_ids.size} teammate#{'s' if teammate_ids.size != 1}."
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
    caches = CheckInHealthCache.where(
      teammate_id: direct_report_ids,
      organization_id: @organization.id
    ).to_a
    aspiration_counts = aggregate_category_counts(caches.flat_map(&:payload_aspirations))
    assignment_counts = aggregate_category_counts(caches.flat_map(&:payload_assignments))
    position_counts = aggregate_position_counts(caches.map { |c| c.payload_position.presence || {} })
    milestone_total = caches.sum { |c| c.payload_milestones['total_required'].to_i }
    milestone_earned = caches.sum { |c| c.payload_milestones['earned_count'].to_i }
    completion_rate = completion_rate_for_caches(caches)
    {
      manager_teammate: manager_teammate,
      aspiration_counts: aspiration_counts,
      assignment_counts: assignment_counts,
      position_counts: position_counts,
      milestone_total_required: milestone_total,
      milestone_earned_count: milestone_earned,
      direct_report_count: direct_report_ids.size,
      completion_rate: completion_rate
    }
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end
end
