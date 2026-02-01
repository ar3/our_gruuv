class CheckInHealthService
  DAYS_THRESHOLD = 90

  def self.call(teammate, organization)
    new(teammate, organization).call
  end

  def initialize(teammate, organization)
    @teammate = teammate
    @organization = organization
  end

  def call
    {
      position: position_health,
      assignments: assignment_health,
      aspirations: aspiration_health,
      milestones: milestone_health
    }
  end

  private

  attr_reader :teammate, :organization

  def position_health
    # Find most recent closed position check-in with official_rating
    latest_finalized = PositionCheckIn
      .where(teammate: teammate)
      .closed
      .where.not(official_rating: nil)
      .order(official_check_in_completed_at: :desc)
      .first

    # Find open position check-in
    open_check_in = PositionCheckIn
      .where(teammate: teammate)
      .open
      .first

    if latest_finalized.nil?
      # No rating ever
      status = :alarm
      last_rating_date = nil
      days_since_rating = nil
    elsif latest_finalized.official_check_in_completed_at < DAYS_THRESHOLD.days.ago
      # Old rating (>90 days)
      status = :warning
      last_rating_date = latest_finalized.official_check_in_completed_at.to_date
      days_since_rating = (Date.current - last_rating_date).to_i
    else
      # Current rating (≤90 days)
      status = :success
      last_rating_date = latest_finalized.official_check_in_completed_at.to_date
      days_since_rating = (Date.current - last_rating_date).to_i
    end

    # Check if there's an open check-in
    if open_check_in
      status = :in_progress if status == :alarm || status == :warning
      open_check_in_started_on = open_check_in.check_in_started_on
      open_unacknowledged = !open_check_in.employee_completed?
    else
      open_check_in_started_on = nil
      open_unacknowledged = false
    end

    {
      status: status,
      last_rating_date: last_rating_date,
      days_since_rating: days_since_rating,
      open_check_in: open_check_in,
      open_check_in_started_on: open_check_in_started_on,
      open_unacknowledged: open_unacknowledged
    }
  end

  def assignment_health
    # Get active assignments for this teammate in this organization
    active_assignments = teammate.assignment_tenures
      .active
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(:assignment)
      .distinct

    total_count = active_assignments.count

    # Count assignments with completed check-ins in last 90 days
    completed_count = active_assignments.to_a.count do |tenure|
      check_in = AssignmentCheckIn
        .where(teammate: teammate, assignment: tenure.assignment)
        .closed
        .where.not(official_check_in_completed_at: nil)
        .where('official_check_in_completed_at >= ?', DAYS_THRESHOLD.days.ago)
        .order(official_check_in_completed_at: :desc)
        .first
      
      check_in.present?
    end

    # Count open/unacknowledged check-ins
    open_check_ins = AssignmentCheckIn
      .where(teammate: teammate)
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .open

    open_count = open_check_ins.count
    unacknowledged_count = open_check_ins.where(employee_completed_at: nil).count

    # Determine status
    if total_count == 0
      status = :alarm
    elsif completed_count == 0 && open_count == 0
      status = :alarm
    elsif completed_count < total_count && (total_count - completed_count - open_count) > 0
      # Some assignments have old or no check-ins
      status = :warning
    elsif open_count > 0
      status = :in_progress
    else
      status = :success
    end

    {
      total_count: total_count,
      completed_count: completed_count,
      open_count: open_count,
      unacknowledged_count: unacknowledged_count,
      status: status
    }
  end

  def aspiration_health
    # Get all aspirations for organization
    aspirations = Aspiration.within_hierarchy(organization)
    total_count = aspirations.count

    # Count aspirations with observation ratings for employee in last 90 days
    # Observations can rate aspirations, so we check observation_ratings
    teammate_observations = Observation
      .joins(:observees)
      .where(observees: { teammate: teammate })
      .where('observed_at >= ?', DAYS_THRESHOLD.days.ago)

    rated_aspiration_ids = teammate_observations
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: 'Aspiration' })
      .pluck('observation_ratings.rateable_id')
      .uniq

    rated_count = aspirations.where(id: rated_aspiration_ids).count

    # Count open/unacknowledged aspiration check-ins
    open_check_ins = AspirationCheckIn
      .where(teammate: teammate)
      .joins(:aspiration)
      .where(aspirations: { company_id: organization.self_and_descendants.pluck(:id) })
      .open

    open_count = open_check_ins.count
    unacknowledged_count = open_check_ins.where(employee_completed_at: nil).count

    # Determine status
    if total_count == 0
      status = :success # No aspirations means nothing to rate
    elsif rated_count == 0 && open_count == 0
      status = :alarm
    elsif rated_count < total_count && (total_count - rated_count - open_count) > 0
      status = :warning
    elsif open_count > 0
      status = :in_progress
    else
      status = :success
    end

    {
      total_count: total_count,
      rated_count: rated_count,
      open_count: open_count,
      unacknowledged_count: unacknowledged_count,
      status: status
    }
  end

  def milestone_health
    # Get active assignments for this teammate
    active_assignments = teammate.assignment_tenures
      .active
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(assignment: :assignment_abilities)

    # Collect all required milestone requirements from assignments
    required_milestones = Set.new
    active_assignments.each do |tenure|
      tenure.assignment.assignment_abilities.each do |assignment_ability|
        required_milestones.add([assignment_ability.ability_id, assignment_ability.milestone_level])
      end
    end

    required_count = required_milestones.count

    # Count milestones employee has attained
    attained_milestones = teammate.teammate_milestones
      .joins(:ability)
      .where(abilities: { company_id: organization.self_and_descendants.pluck(:id) })

    # Check if employee has attained each required milestone
    attained_count = required_milestones.count do |(ability_id, milestone_level)|
      attained_milestones.any? do |tm|
        tm.ability_id == ability_id && tm.milestone_level >= milestone_level
      end
    end

    # Determine status
    if required_count == 0
      status = :success # No requirements means nothing to attain
    elsif attained_count == 0
      status = :alarm
    elsif attained_count < required_count
      status = :warning
    else
      status = :success
    end

    {
      required_count: required_count,
      attained_count: attained_count,
      status: status
    }
  end
end

