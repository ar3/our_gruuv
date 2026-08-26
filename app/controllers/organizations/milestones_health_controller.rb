# frozen_string_literal: true

class Organizations::MilestonesHealthController < Organizations::OrganizationNamespaceBaseController
  include Organizations::HealthNudgeActions

  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :milestones_health?
    apply_filter_default_if_needed

    data = milestones_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])
    all_rows = data[:rows]
    @spotlight_stats = data[:spotlight_stats]

    @pagy = Pagy.new(count: all_rows.count, page: params[:page] || 1, items: 25)
    @employee_rows = all_rows[@pagy.offset, @pagy.items]
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = milestones_health_spotlight_service.available_manager_filter_options
    assign_health_nudge_context!(health_object: "milestones_health", spotlight_stats: @spotlight_stats)
  end

  def nudge
    authorize @organization, :milestones_health?
    apply_filter_default_if_needed

    spotlight_stats = milestones_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])[:spotlight_stats]
    perform_health_nudge!(
      health_object: "milestones_health",
      spotlight_stats: spotlight_stats,
      redirect_path: organization_milestones_health_path(@organization, manager_id: params[:manager_id])
    )
  end

  def export_employee_summary
    authorize @organization, :milestones_health?
    apply_filter_default_if_needed

    rows = milestones_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])[:rows]
    csv_content = MilestonesHealthEmployeeSummaryCsvBuilder.new(rows).call
    filename = "employee_milestones_health_summary_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  def refresh
    authorize @organization, :milestones_health?

    teammate = @organization.teammates.find_by(id: params[:teammate_id])
    unless teammate
      redirect_back fallback_location: organization_milestones_health_path(@organization),
                    alert: "Could not refresh: teammate not found."
      return
    end

    EngagementHealth.schedule_refresh_for(teammate.id)
    redirect_back fallback_location: organization_milestones_health_path(@organization),
                  notice: "Gruuv Health refresh queued for #{teammate.person.display_name}."
  end

  def refresh_all
    authorize @organization, :milestones_health?
    apply_filter_default_if_needed

    teammate_ids = milestones_health_spotlight_service.filtered_teammate_ids(params[:manager_id])
    teammate_ids.each { |teammate_id| EngagementHealth.schedule_refresh_for(teammate_id) }

    redirect_to organization_milestones_health_path(@organization, manager_id: params[:manager_id]),
                notice: "Gruuv Health refresh queued for #{teammate_ids.size} teammate#{'s' if teammate_ids.size != 1}."
  end

  private

  def milestones_health_spotlight_service
    @milestones_health_spotlight_service ||= MilestonesHealthSpotlightService.new(
      organization: @organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: policy(@organization).manage_employment?
    )
  end

  def apply_filter_default_if_needed
    return if params[:manager_id].present?

    params[:manager_id] = milestones_health_spotlight_service.default_manager_filter_value
  end

  def health_nudge_manager_filter_viewable?(manager_id)
    milestones_health_spotlight_service.filtering.manager_filter_viewable?(manager_id)
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
