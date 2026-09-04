# frozen_string_literal: true

class Organizations::ValuesHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :values_health?
    @overview = overview_service.call
    assign_values_check_in_clarity!
  end

  def refresh
    authorize @organization, :values_health?

    aspiration = find_active_aspiration(params[:aspiration_id])
    unless aspiration
      redirect_back fallback_location: organization_values_health_path(@organization),
                    alert: "Could not refresh: value not found."
      return
    end

    AspirationExpectationAlignmentScoreRefreshJob.perform_later(aspiration.id)
    redirect_back fallback_location: organization_values_health_path(@organization),
                  notice: "Expectation Alignment Score refresh queued for #{aspiration.name}."
  end

  def refresh_missing_and_stale
    authorize @organization, :values_health?

    ids = overview_service.call.refreshable_aspiration_ids
    ids.each { |aspiration_id| AspirationExpectationAlignmentScoreRefreshJob.perform_later(aspiration_id) }

    redirect_to organization_values_health_path(@organization),
                notice: refresh_notice(ids.size)
  end

  private

  def overview_service
    @overview_service ||= ValuesHealth::ExpectationAlignmentOverview.new(organization: @organization)
  end

  def assign_values_check_in_clarity!
    @can_manage_employment = policy(@organization).manage_employment?
    @clarity_display = params[:display].to_s == 'names' ? 'names' : 'dots'

    clarity_teammates = CompanyTeammate
      .for_organization_hierarchy(@organization)
      .where.not(first_employed_at: nil)
      .where(last_terminated_at: nil)
      .includes(:person)
      .to_a
    aspirations = Aspiration.for_company(@organization).includes(:department).ordered.to_a
    @clarity_query = Insights::AspirationRatingAlignmentQuery.new(
      teammates: clarity_teammates,
      aspirations: aspirations
    )
  end

  def find_active_aspiration(aspiration_id)
    Aspiration.for_company(@organization).find_by(id: aspiration_id)
  end

  def refresh_notice(count)
    if count.zero?
      "No missing or stale Expectation Alignment Scores to refresh."
    else
      "Expectation Alignment Score refresh queued for #{count} value#{'s' if count != 1}."
    end
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
