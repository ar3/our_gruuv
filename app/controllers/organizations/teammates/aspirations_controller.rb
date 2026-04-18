class Organizations::Teammates::AspirationsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::LoadAssociableGoalsDisplay

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_aspiration
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    @organization = organization
    @person = @teammate.person

    # Single-item layout
    @single_item_type = :aspiration
    @single_item_id = @aspiration.id
    @single_item_name = @aspiration.name

    # Finalized only for single-item prior check-ins table
    @check_ins_finalized = AspirationCheckIn
      .where(company_teammate: @teammate, aspiration: @aspiration)
      .closed
      .includes(:manager_completed_by_teammate, :finalized_by_teammate)
      .order(official_check_in_completed_at: :desc)

    # Full history (all) for legacy "All Check-ins" table on page
    @check_ins = AspirationCheckIn
      .where(company_teammate: @teammate, aspiration: @aspiration)
      .includes(:manager_completed_by_teammate, :finalized_by_teammate, :maap_snapshot)
      .order(check_in_started_on: :desc)

    @open_check_in = AspirationCheckIn.find_or_create_open_for(@teammate, @aspiration)
    @latest_finalized = AspirationCheckIn.latest_finalized_for(@teammate, @aspiration)
    @latest_finalized_for_pill = @latest_finalized

    next_result = CheckIns::SingleItemCheckInNextItemService.call(
      teammate: @teammate,
      organization: organization,
      current_person: current_person,
      current_type: :aspiration,
      current_id: @aspiration.id
    )
    @single_item_ordered_items = next_result[:ordered_items]
    @single_item_next_requires_check_in = next_result[:next_requires_check_in]
    @single_item_next_item = next_result[:next_item]
    @single_item_next_url = next_result[:next_url]
    @single_item_show_check_in_status_done = next_result[:show_check_in_status_done]

    @check_in_health_cache = CheckInHealthCache.find_by(teammate: @teammate, organization: organization)

    since_date = @latest_finalized&.official_check_in_completed_at || 10.years.ago
    @observations_since_date = since_date
    @observations_has_finalized_check_in = @latest_finalized.present?
    observations_params = {
      observee_ids: [@teammate.id],
      rateable_type: "Aspiration",
      rateable_id: @aspiration.id,
      timeframe: "between",
      timeframe_start_date: since_date.to_date.to_s,
      timeframe_end_date: Time.current.to_date.to_s
    }
    observations_query = ObservationsQuery.new(organization, observations_params, current_person: current_person)
    @observations_since_finalized = observations_query.call
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: "Aspiration", rateable_id: @aspiration.id })
      .distinct
      .includes(:observer, :observed_teammates, :observation_ratings)
      .order(observed_at: :desc)
      .limit(50)
    @observations_involving_url = organization_observations_path(
      organization,
      observee_ids: [@teammate.id],
      rateable_type: "Aspiration",
      rateable_id: @aspiration.id,
      return_url: organization_teammate_aspiration_path(organization, @teammate, @aspiration),
      return_text: "Back to 1-by-1 check-in"
    )
    @observations_new_observation_url = new_organization_observation_path(
      organization,
      observee_ids: [@teammate.id],
      rateable_type: "Aspiration",
      rateable_id: @aspiration.id,
      return_url: organization_teammate_aspiration_path(organization, @teammate, @aspiration),
      return_text: "Back to 1-by-1 check-in"
    )

    load_associable_goals_display!(@aspiration)
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def set_aspiration
    @aspiration = Aspiration.find(params[:id])
  end
end

