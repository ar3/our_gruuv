class GetShitDoneQueryService
  attr_reader :teammate, :person, :company

  def initialize(teammate:)
    @teammate = teammate
    @person = teammate&.person
    @company = teammate&.organization
  end

  def observable_moments
    return ObservableMoment.none unless teammate
    
    ObservableMoment.for_observer(teammate).recent
  end

  def maap_snapshots
    # Legacy name kept for GSD callers; pending is now check-in acknowledgement count.
    # Returns an empty relation; use pending_acknowledgement_count for the number.
    MaapSnapshot.none
  end

  def pending_acknowledgement_count
    return 0 unless teammate

    pending_acknowledgement_queue.count
  end

  def pending_acknowledgement_queue
    return empty_acknowledgement_queue unless teammate

    CheckIns::AcknowledgementQueue.for(teammate: teammate)
  end

  def observation_drafts
    return Observation.none unless person && company
    
    Observation.where(observer: person, company: company)
               .drafts
               .where.not(privacy_level: :observer_only)
               .where(deleted_at: nil)
               .recent
  end

  # Published, non-journal observations you authored with no notifications yet (same criteria as the observation show nudge).
  def silent_observations
    return Observation.none unless person && company

    Observation.where(observer: person, company: company)
               .published
               .not_journal
               .not_soft_deleted
               .without_notifications
               .without_gsd_notification_skip
               .recent
  end

  # Published Feedback OGOs you authored that still lack a constructive rating.
  def feedback_expectation_mismatches
    return Observation.none unless person && company

    Observations::FeedbackExpectation.without_constructive_ratings(
      Observation.where(observer: person, company: company)
                 .published
                 .not_journal
                 .not_soft_deleted
    ).recent
  end

  # Open feedback requests where this teammate is a named/incomplete responder.
  def feedback_requests_awaiting_response
    return FeedbackRequest.none unless teammate && company

    FeedbackRequest
      .not_deleted
      .where(company: company)
      .joins(:feedback_request_responders)
      .where(feedback_request_responders: { teammate_id: teammate.id, completed_at: nil })
      .includes(
        :requestor_teammate,
        { subject_of_feedback_teammate: :person },
        :feedback_request_questions
      )
      .distinct
      .order(created_at: :desc)
  end

  def goals_needing_check_in
    return Goal.none unless teammate
    
    GoalsNeedingCheckInQuery.new(teammate: teammate).call
  end

  def check_ins_awaiting_input
    return [] unless teammate

    as_employee = check_ins_awaiting_employee_input
    as_manager = check_ins_awaiting_manager_input
    (as_employee + as_manager).sort_by(&:check_in_started_on).reverse
  end

  def total_pending_count
    observable_moments.count +
      pending_acknowledgement_count +
      observation_drafts.count +
      silent_observations.count +
      feedback_expectation_mismatches.count +
      feedback_requests_awaiting_response.count +
      goals_needing_check_in.count +
      check_ins_awaiting_input.size
  end

  def all_pending_items
    {
      observable_moments: observable_moments,
      maap_snapshots: maap_snapshots,
      pending_acknowledgements: pending_acknowledgement_queue.items,
      pending_acknowledgement_count: pending_acknowledgement_count,
      observation_drafts: observation_drafts,
      silent_observations: silent_observations,
      feedback_expectation_mismatches: feedback_expectation_mismatches,
      feedback_requests_awaiting_response: feedback_requests_awaiting_response,
      goals_needing_check_in: goals_needing_check_in,
      check_ins_awaiting_input: check_ins_awaiting_input,
      total_pending: total_pending_count
    }
  end

  # Non-zero counts only, same section order and labels as organizations/get_shit_done/show.
  def pending_category_breakdown
    return [] unless teammate

    [
      { count: observable_moments.count, label: "Observable Moments" },
      { count: pending_acknowledgement_count, label: I18n.t("terminology.clarity_check_ins_awaiting_acknowledgement") },
      { count: check_ins_awaiting_input.size, label: I18n.t("terminology.clarity_check_ins_awaiting_your_input") },
      { count: goals_needing_check_in.count, label: I18n.t("terminology.goal_confidence_checks") },
      { count: observation_drafts.count, label: "Observation Drafts" },
      { count: silent_observations.count, label: "Silent Observations" },
      { count: feedback_expectation_mismatches.count, label: "Feedback to clean up" },
      { count: feedback_requests_awaiting_response.count, label: "Feedback Requests" }
    ].select { |row| row[:count].positive? }
  end

  private

  def empty_acknowledgement_queue
    CheckIns::AcknowledgementQueue::Result.new(
      position_check_in: nil,
      assignment_check_ins: [],
      aspiration_check_ins: []
    )
  end

  def check_ins_awaiting_employee_input
    [AssignmentCheckIn, AspirationCheckIn, PositionCheckIn].flat_map do |klass|
      klass.for_teammate(teammate).awaiting_employee_input.to_a
    end
  end

  def check_ins_awaiting_manager_input
    direct_report_ids = EmploymentTenure
      .where(manager_teammate: teammate, company: company, ended_at: nil)
      .pluck(:teammate_id)
    return [] if direct_report_ids.empty?

    [AssignmentCheckIn, AspirationCheckIn, PositionCheckIn].flat_map do |klass|
      klass.where(teammate_id: direct_report_ids).awaiting_manager_input.to_a
    end
  end
end
