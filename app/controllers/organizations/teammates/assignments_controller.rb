class Organizations::Teammates::AssignmentsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::LoadAssociableGoalsDisplay
  include Organizations::AssignsViewableTeammates

  helper AssignmentEnergyAllocationHelper

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_assignment
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    @organization = organization
    @person = @teammate.person
    assign_viewable_teammates_context!(selected_teammate: @teammate)

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

    @engagement_health_records = EngagementHealth::ClarityMetrics.records_for_teammate(
      organization: organization,
      teammate_id: @teammate.id
    )

    @assignment_survey_due_status = AssignmentSurveys::DueStatus.for(
      teammate: @teammate,
      assignment: @assignment
    )
    @assignment_survey_responses = @teammate.assignment_survey_responses
      .submitted
      .where(organization: organization, assignment: @assignment)
      .latest_submitted_first
      .to_a
    @latest_assignment_survey_response = @assignment_survey_responses.first
    @viewer_is_check_in_employee = current_person == @teammate.person

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
      timeframe_end_date: Time.current.to_date.to_s,
      include_viewer_drafts: true
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

    @show_assignment_energy_bars = current_person == @teammate.person
    if @show_assignment_energy_bars
      reflection_check_ins = AssignmentCheckIn
        .joins(:assignment)
        .where(company_teammate: @teammate, assignments: { company: organization })
        .open
        .includes(:assignment)
      @assignment_energy_allocation = CheckIns::AssignmentEnergyAllocationSummary.for_bulk_check_in(
        teammate: @teammate,
        reflection_check_ins: reflection_check_ins,
        organization: organization
      )
      @assignment_energy_manager_name = @teammate.current_manager&.casual_name.presence || "your manager"
    end

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

  def force_close_open_check_in
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    open_check_in = AssignmentCheckIn.where(company_teammate: @teammate, assignment: @assignment).open.first
    return redirect_to assignment_show_path, alert: "No open check-in found to force close." if open_check_in.blank?

    viewer_role = current_person == @teammate.person ? :employee : :manager
    if open_check_in.active_assignment_tenure?
      return redirect_to assignment_show_path,
        alert: "Active assignments can't force close check-ins."
    end
    unless open_check_in.force_closeable_by_viewer_role?(viewer_role)
      return redirect_to assignment_show_path,
        alert: "This check-in can't be force closed because the manager still has values entered."
    end

    closed_by = current_company_teammate
    unless closed_by
      return redirect_to assignment_show_path, alert: "Could not force close this check-in."
    end

    if open_check_in.force_close!(closed_by_teammate: closed_by)
      CheckIns::NotifyForceCloseJob.perform_later(
        check_in_id: open_check_in.id,
        organization_id: organization.id,
        closed_by_teammate_id: closed_by.id
      )
      redirect_to assignment_show_path, notice: "That check-in was force closed."
    else
      redirect_to assignment_show_path, alert: "Could not force close this check-in."
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

