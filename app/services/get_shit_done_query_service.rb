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

  def total_pending_count
    observable_moments.count +
      maap_snapshots.count +
      observation_drafts.count +
      goals_needing_check_in.count
  end

  def all_pending_items
    {
      observable_moments: observable_moments,
      maap_snapshots: maap_snapshots,
      observation_drafts: observation_drafts,
      goals_needing_check_in: goals_needing_check_in,
      total_pending: total_pending_count
    }
  end
end
