# frozen_string_literal: true

class Organizations::ObservationsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :observations_health?
    apply_filter_default_if_needed

    data = observations_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])
    all_rows = data[:rows]
    @spotlight_stats = data[:spotlight_stats]

    @pagy = Pagy.new(count: all_rows.count, page: params[:page] || 1, items: 25)
    @employee_rows = all_rows[@pagy.offset, @pagy.items]
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = observations_health_spotlight_service.available_manager_filter_options
  end

  def refresh
    authorize @organization, :observations_health?

    teammate = @organization.teammates.find_by(id: params[:teammate_id])
    unless teammate
      redirect_back fallback_location: organization_observations_health_path(@organization),
                    alert: "Could not refresh: teammate not found."
      return
    end

    ObservationHealthCacheRefreshJob.perform_later(teammate.id)
    redirect_back fallback_location: organization_observations_health_path(@organization),
                  notice: "Refresh queued for #{teammate.person.display_name}."
  end

  def refresh_all
    authorize @organization, :observations_health?
    apply_filter_default_if_needed

    teammate_ids = observations_health_spotlight_service.filtered_teammates(params[:manager_id]).pluck(:id)
    teammate_ids.each { |teammate_id| ObservationHealthCacheRefreshJob.perform_later(teammate_id) }

    redirect_to organization_observations_health_path(@organization, manager_id: params[:manager_id]),
                notice: "Refresh queued for #{teammate_ids.size} teammate#{'s' if teammate_ids.size != 1}."
  end

  def export
    authorize @organization, :observations_health?
    apply_filter_default_if_needed

    teammates = observations_health_spotlight_service.filtered_teammates(params[:manager_id]).to_a
    csv_content = ObservationsHealthObservationsCsvBuilder.new(
      @organization,
      teammates,
      current_person: current_person
    ).call
    filename = "observations_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  def export_employee_summary
    authorize @organization, :observations_health?
    apply_filter_default_if_needed

    rows = observations_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])[:rows]
    csv_content = ObservationsHealthEmployeeSummaryCsvBuilder.new(rows).call
    filename = "employee_observations_health_summary_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def observations_health_spotlight_service
    @observations_health_spotlight_service ||= ObservationsHealthSpotlightService.new(
      organization: @organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: policy(@organization).manage_employment?
    )
  end

  def apply_filter_default_if_needed
    return if params[:manager_id].present?

    params[:manager_id] = observations_health_spotlight_service.default_manager_filter_value
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
