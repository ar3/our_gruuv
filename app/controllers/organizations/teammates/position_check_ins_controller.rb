# frozen_string_literal: true

class Organizations::Teammates::PositionCheckInsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy

    @organization = organization
    @person = @teammate.person
    @current_employment = @teammate.employment_tenures.active.includes(position: :title).first
    @position = @current_employment&.position

    # Single-item layout: object type for partials
    @single_item_type = :position
    @single_item_id = nil
    @single_item_name = @position&.title&.external_title.presence || "Position"

    # Check-ins: full history (finalized) for prior table, open for form
    @check_ins = PositionCheckIn
      .where(company_teammate: @teammate)
      .closed
      .includes(:finalized_by_teammate, :manager_completed_by_teammate, :employment_tenure)
      .order(official_check_in_completed_at: :desc)

    @open_check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    @latest_finalized = PositionCheckIn.latest_finalized_for(@teammate)

    # Header: switcher items and next-item (for button state)
    next_result = CheckIns::SingleItemCheckInNextItemService.call(
      teammate: @teammate,
      organization: organization,
      current_person: current_person,
      current_type: :position,
      current_id: nil
    )
    @single_item_ordered_items = next_result[:ordered_items]
    @single_item_next_requires_check_in = next_result[:next_requires_check_in]
    @single_item_next_item = next_result[:next_item]
    @single_item_next_url = next_result[:next_url]
    @single_item_show_check_in_status_done = next_result[:show_check_in_status_done]

    # Last finalized pill uses position-level latest
    @latest_finalized_for_pill = @latest_finalized

    # Clarity % (check-in health cache)
    @check_in_health_cache = CheckInHealthCache.find_by(teammate: @teammate, organization: organization)

    # Prior check-ins: already loaded as @check_ins (finalized only)

    # Current period observations: teammate as observee, since last finalized (or all if none)
    since_date = @latest_finalized&.official_check_in_completed_at || 10.years.ago
    @observations_since_date = since_date
    @observations_has_finalized_check_in = @latest_finalized.present?
    observations_params = {
      observee_ids: [@teammate.id],
      timeframe: "between",
      timeframe_start_date: since_date.to_date.to_s,
      timeframe_end_date: Time.current.to_date.to_s
    }
    observations_query = ObservationsQuery.new(organization, observations_params, current_person: current_person)
    @observations_since_finalized = observations_query.call
      .includes(:observer, :observed_teammates, :observation_ratings)
      .order(observed_at: :desc)
      .limit(50)

    position_check_in_return_path = position_check_in_organization_teammate_path(organization, @teammate)
    @observations_involving_url = organization_observations_path(
      organization,
      observee_ids: [@teammate.id],
      return_url: position_check_in_return_path,
      return_text: "Back to 1-by-1 check-in"
    )
    @observations_new_observation_url = new_organization_observation_path(
      organization,
      observee_ids: [@teammate.id],
      return_url: position_check_in_return_path,
      return_text: "Back to 1-by-1 check-in"
    )

    render "organizations/teammates/position_check_ins/show"
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:id])
  end
end
