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
    return MaapSnapshot.none unless teammate
    
    MaapSnapshot.pending_acknowledgement_for(teammate).recent
  end

  def observation_drafts
    return Observation.none unless person && company
    
    Observation.where(observer: person, company: company)
               .drafts
               .where.not(privacy_level: :observer_only)
               .where(deleted_at: nil)
               .recent
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
      maap_snapshots.count +
      observation_drafts.count +
      goals_needing_check_in.count +
      check_ins_awaiting_input.size
  end

  def all_pending_items
    {
      observable_moments: observable_moments,
      maap_snapshots: maap_snapshots,
      observation_drafts: observation_drafts,
      goals_needing_check_in: goals_needing_check_in,
      check_ins_awaiting_input: check_ins_awaiting_input,
      total_pending: total_pending_count
    }
  end

  private

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
