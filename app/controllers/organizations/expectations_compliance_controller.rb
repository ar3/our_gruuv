# frozen_string_literal: true

class Organizations::ExpectationsComplianceController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :expectations_compliance?
    apply_filter_default_if_needed

    teammates = filter_service.filtered_teammates(params[:manager_id]).includes(:person).to_a
    all_rows = ExpectationsCompliance::Roster.call(organization: @organization, teammates: teammates)

    @pagy = Pagy.new(count: all_rows.count, page: params[:page] || 1, items: 25)
    @rows = all_rows[@pagy.offset, @pagy.items]
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = filter_service.available_manager_filter_options
    @compliant_count = all_rows.count(&:compliant)
    @needs_attention_count = all_rows.size - @compliant_count
  end

  private

  def filter_service
    @filter_service ||= GoalsHealthSpotlightService.new(
      organization: @organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: policy(@organization).manage_employment?
    )
  end

  def apply_filter_default_if_needed
    return if params[:manager_id].present?

    params[:manager_id] = filter_service.default_manager_filter_value
  end

  def require_authentication
    return if current_person

    redirect_unauthenticated_to_login!(message: "Please log in to access this page.", flash_key: :alert)
  end
end
