class Organizations::Teammates::AssignmentsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::LoadAssociableGoalsDisplay

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_assignment
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    @organization = organization
    @person = @teammate.person

    # Single-item layout
    @single_item_type = :assignment
    @single_item_id = @assignment.id
    @single_item_name = @assignment.title

    # Load assignment details
    @assignment_outcomes = @assignment.assignment_outcomes.ordered
    @assignment_abilities = @assignment.assignment_abilities.includes(:ability)

    # Load tenure history
    @tenure_history = AssignmentTenure
      .where(company_teammate: @teammate, assignment: @assignment)
      .order(started_at: :desc)

    # Finalized check-ins for prior table (single-item format)
    @check_ins_finalized = AssignmentCheckIn
      .where(company_teammate: @teammate, assignment: @assignment)
      .closed
      .includes(:manager_completed_by_teammate, :finalized_by_teammate)
      .order(official_check_in_completed_at: :desc)

    # All check-ins (full history) for All Check-ins table
    @check_ins = AssignmentCheckIn
      .where(company_teammate: @teammate, assignment: @assignment)
      .includes(:manager_completed_by_teammate, :finalized_by_teammate, :maap_snapshot)
      .order(check_in_started_on: :desc)

    @open_check_in = if @assignment.required_on_position_for_teammate?(@teammate, organization)
      AssignmentCheckIn.find_or_create_open_for(@teammate, @assignment)
    else
      AssignmentCheckIn.where(company_teammate: @teammate, assignment: @assignment).open.first
    end
    @latest_finalized = AssignmentCheckIn.latest_finalized_for(@teammate, @assignment)
    @latest_finalized_for_pill = @latest_finalized

    next_result = CheckIns::SingleItemCheckInNextItemService.call(
      teammate: @teammate,
      organization: organization,
      current_person: current_person,
      current_type: :assignment,
      current_id: @assignment.id
    )
    @single_item_ordered_items = next_result[:ordered_items]
    @single_item_next_requires_check_in = next_result[:next_requires_check_in]
    @single_item_next_item = next_result[:next_item]
    @single_item_next_url = next_result[:next_url]
    @single_item_show_check_in_status_done = next_result[:show_check_in_status_done]

    @check_in_health_cache = CheckInHealthCache.find_by(teammate: @teammate, organization: organization)

    # Get current employment for position connection
    @current_employment = @teammate.employment_tenures.active.first
    @position_assignment = nil
    if @current_employment&.position&.title
      @position_assignment = PositionAssignment.joins(:position)
        .where(assignment: @assignment)
        .where(positions: { title: @current_employment.position.title })
        .first
    end

    since_date = @latest_finalized&.official_check_in_completed_at || 10.years.ago
    @observations_since_date = since_date
    @observations_has_finalized_check_in = @latest_finalized.present?
    observations_params = {
      observee_ids: [@teammate.id],
      rateable_type: "Assignment",
      rateable_id: @assignment.id,
      timeframe: "between",
      timeframe_start_date: since_date.to_date.to_s,
      timeframe_end_date: Time.current.to_date.to_s
    }
    observations_query = ObservationsQuery.new(organization, observations_params, current_person: current_person)
    @observations_since_finalized = observations_query.call
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: "Assignment", rateable_id: @assignment.id })
      .distinct
      .includes(:observer, :observed_teammates, :observation_ratings)
      .order(observed_at: :desc)
      .limit(50)
    @observations_involving_url = organization_observations_path(
      organization,
      observee_ids: [@teammate.id],
      rateable_type: "Assignment",
      rateable_id: @assignment.id,
      return_url: organization_teammate_assignment_path(organization, @teammate, @assignment),
      return_text: I18n.t("terminology.back_to_one_by_one_clarity_check_in")
    )
    @observations_new_observation_url = new_organization_observation_path(
      organization,
      observee_ids: [@teammate.id],
      rateable_type: "Assignment",
      rateable_id: @assignment.id,
      return_url: organization_teammate_assignment_path(organization, @teammate, @assignment),
      return_text: I18n.t("terminology.back_to_one_by_one_clarity_check_in")
    )

    load_associable_goals_display!(@assignment, subject_teammate: @teammate)
  end

  def start_check_in
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    AssignmentCheckIn.find_or_create_open_for(@teammate, @assignment)
    redirect_to assignment_show_path(anchor: "check-in"), notice: "Check-in started."
  end

  def destroy_open_check_in
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    open_check_in = AssignmentCheckIn.where(company_teammate: @teammate, assignment: @assignment).open.first
    return redirect_to assignment_show_path, alert: "No open check-in found to delete." if open_check_in.blank?

    viewer_role = current_person == @teammate.person ? :employee : :manager
    if open_check_in.assignment.required_on_position_for_teammate?(@teammate, organization)
      return redirect_to assignment_show_path,
        alert: "This check-in can't be deleted because it's a required assignment for this position."
    end
    unless open_check_in.deletable_by_viewer_role?(viewer_role)
      return redirect_to assignment_show_path,
        alert: "This check-in cannot be deleted yet because the other person still has values entered."
    end

    if open_check_in.destroy
      redirect_to assignment_show_path, notice: "That open check-in was deleted."
    else
      redirect_to assignment_show_path,
        alert: "Could not delete this check-in. Please clear any dependent records first."
    end
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:teammate_id])
  end

  def set_assignment
    @assignment = Assignment.find(params[:id])
  end

  def assignment_show_path(**options)
    organization_teammate_assignment_path(organization, @teammate, @assignment, **options)
  end
end

