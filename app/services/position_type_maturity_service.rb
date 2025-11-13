class PositionTypeMaturityService
  def initialize(position_type)
    @position_type = position_type
  end

  def self.calculate_phase(position_type)
    new(position_type).calculate_phase
  end

  def self.next_steps_message(position_type)
    new(position_type).next_steps_message
  end

  def self.phase_status(position_type)
    new(position_type).phase_status
  end

  def calculate_phase
    return 1 unless phase_one_met?
    return 2 unless phase_two_met?
    return 3 unless phase_three_met?
    return 4 unless phase_four_met?
    return 5 unless phase_five_met?
    return 6 unless phase_six_met?
    return 7 unless phase_seven_met?
    return 8 unless phase_eight_met?
    return 9 unless phase_nine_met?
    9
  end

  def phase_status
    [
      phase_one_met?,
      phase_two_met?,
      phase_three_met?,
      phase_four_met?,
      phase_five_met?,
      phase_six_met?,
      phase_seven_met?,
      phase_eight_met?,
      phase_nine_met?
    ]
  end

  def next_steps_message
    current_phase = calculate_phase
    return "Congratulations! You've reached Phase 9 - the highest level of MAAP maturity." if current_phase == 9

    case current_phase
    when 1
      "Next: Ensure all positions have at least one required assignment."
    when 2
      "Next: Have employees with employment tenures complete check-ins on their required assignments."
    when 3
      "Next: Add ability requirements (milestones) to all required assignments."
    when 4
      "Next: Define at least 2 milestones for each ability used in assignments."
    when 5
      "Next: Have employees earn milestones for the abilities required by their assignments."
    when 6
      "Next: Add eligibility requirements summaries to all positions."
    when 7
      "Next: Ensure at least 5% of Abilities, Assignments, and Positions are updated in the last 6 months."
    when 8
      "Next: Publish observations for at least 10% of Abilities, Assignments, and Positions in the last 6 months."
    else
      "Getting started: Add at least one required assignment to a position."
    end
  end

  private

  attr_reader :position_type

  # Phase 1: At least one position has ≥1 required assignment
  def phase_one_met?
    position_type.positions.joins(:position_assignments)
                  .where(position_assignments: { assignment_type: 'required' })
                  .exists?
  end

  # Phase 2: All positions have ≥1 required assignment
  def phase_two_met?
    positions = position_type.positions
    return false if positions.empty?
    
    positions.all? do |position|
      position.position_assignments.where(assignment_type: 'required').exists?
    end
  end

  # Phase 3: At least one position has employment_tenure AND there exists ≥1 AssignmentCheckIn for required assignments
  def phase_three_met?
    # Check if any position has an employment tenure
    positions_with_tenures = position_type.positions
                                         .joins(:employment_tenures)
                                         .distinct

    return false if positions_with_tenures.empty?

    # Get all required assignments for positions with tenures
    required_assignments = PositionAssignment
      .where(position: positions_with_tenures, assignment_type: 'required')
      .includes(:assignment)
      .map(&:assignment)

    return false if required_assignments.empty?

    # Check if there's at least one AssignmentCheckIn for any of these assignments
    # We need to find teammates associated with employment tenures for these positions
    employment_tenures = EmploymentTenure
      .where(position: positions_with_tenures)
      .includes(:teammate)

    teammates = employment_tenures.map(&:teammate).compact.uniq

    return false if teammates.empty?

    # Check for AssignmentCheckIns for these teammates and required assignments
    AssignmentCheckIn
      .where(teammate: teammates, assignment: required_assignments)
      .exists?
  end

  # Phase 4: All required assignments have ≥1 AssignmentAbility
  def phase_four_met?
    # Get all required assignments for positions in this position type
    required_assignment_ids = PositionAssignment
      .joins(:position)
      .where(positions: { position_type_id: position_type.id })
      .where(assignment_type: 'required')
      .distinct
      .pluck(:assignment_id)

    return false if required_assignment_ids.empty?

    # Check if all required assignments have at least one ability requirement
    assignments_with_abilities = AssignmentAbility
      .where(assignment_id: required_assignment_ids)
      .distinct
      .pluck(:assignment_id)

    assignments_with_abilities.length == required_assignment_ids.length
  end

  # Phase 5: All abilities have milestone_1_description AND milestone_2_description
  def phase_five_met?
    # Get all abilities used in required assignments
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { position_type_id: position_type.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct

    return false if abilities.empty?

    # Check that all abilities have both milestone_1_description and milestone_2_description
    abilities.all? do |ability|
      ability.milestone_1_description.present? && ability.milestone_2_description.present?
    end
  end

  # Phase 6: All abilities have ≥1 TeammateMilestone
  def phase_six_met?
    # Get all abilities used in required assignments
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { position_type_id: position_type.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct

    return false if abilities.empty?

    # Check that all abilities have at least one teammate milestone
    abilities.all? do |ability|
      ability.teammate_milestones.exists?
    end
  end

  # Phase 7: All positions have non-nil eligibility_requirements_summary
  def phase_seven_met?
    positions = position_type.positions
    return false if positions.empty?

    positions.all? do |position|
      position.eligibility_requirements_summary.present?
    end
  end

  # Phase 8: ≥5% of Abilities/Assignments/Positions updated in last 6 months
  def phase_eight_met?
    six_months_ago = 6.months.ago

    # Get all related entities
    positions = position_type.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { position_type_id: position_type.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { position_type_id: position_type.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = positions.length + assignments.length + abilities.length
    return false if total_entities == 0

    # Count entities updated in last 6 months
    updated_count = 0
    updated_count += positions.count { |p| p.updated_at >= six_months_ago }
    updated_count += assignments.count { |a| a.updated_at >= six_months_ago }
    updated_count += abilities.count { |a| a.updated_at >= six_months_ago }

    percentage = (updated_count.to_f / total_entities) * 100
    percentage >= 5.0
  end

  # Phase 9: ≥10% have published Observations (published_at in last 6 months)
  def phase_nine_met?
    six_months_ago = 6.months.ago

    # Get all related entities
    positions = position_type.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { position_type_id: position_type.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { position_type_id: position_type.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = positions.length + assignments.length + abilities.length
    return false if total_entities == 0

    # Count entities with published observations in last 6 months
    observed_count = 0

    # Check positions (via observation_ratings)
    position_ids = positions.map(&:id)
    observed_count += ObservationRating
      .where(rateable_type: 'Position', rateable_id: position_ids)
      .joins(:observation)
      .where(observations: { published_at: six_months_ago.. })
      .distinct
      .pluck(:rateable_id)
      .length

    # Check assignments
    assignment_ids = assignments.map(&:id)
    observed_count += ObservationRating
      .where(rateable_type: 'Assignment', rateable_id: assignment_ids)
      .joins(:observation)
      .where(observations: { published_at: six_months_ago.. })
      .distinct
      .pluck(:rateable_id)
      .length

    # Check abilities
    ability_ids = abilities.map(&:id)
    observed_count += ObservationRating
      .where(rateable_type: 'Ability', rateable_id: ability_ids)
      .joins(:observation)
      .where(observations: { published_at: six_months_ago.. })
      .distinct
      .pluck(:rateable_id)
      .length

    percentage = (observed_count.to_f / total_entities) * 100
    percentage >= 10.0
  end
end

