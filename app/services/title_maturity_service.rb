class TitleMaturityService
  def initialize(title)
    @title = title
  end

  def self.calculate_phase(title)
    new(title).calculate_phase
  end

  def self.next_steps_message(title)
    new(title).next_steps_message
  end

  def self.phase_status(title)
    new(title).phase_status
  end

  def self.phase_health_status(title)
    new(title).phase_health_status
  end

  def self.phase_health_reason(title, phase)
    new(title).phase_health_reason(phase)
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
    return 8 unless phase_nine_met?  # If phase 8 is met but phase 9 is not, return 8
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

  def phase_health_status
    [
      safe_phase_health(1) { phase_one_health },
      safe_phase_health(2) { phase_two_health },
      safe_phase_health(3) { phase_three_health },
      safe_phase_health(4) { phase_four_health },
      safe_phase_health(5) { phase_five_health },
      safe_phase_health(6) { phase_six_health },
      safe_phase_health(7) { phase_seven_health },
      safe_phase_health(8) { phase_eight_health },
      safe_phase_health(9) { phase_nine_health }
    ]
  end

  def safe_phase_health(phase_number)
    yield || :red
  rescue => e
    Rails.logger.error "Error calculating phase #{phase_number} health: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    :red
  end

  def phase_health_reason(phase)
    case phase
    when 1
      phase_one_reason
    when 2
      phase_two_reason
    when 3
      phase_three_reason
    when 4
      phase_four_reason
    when 5
      phase_five_reason
    when 6
      phase_six_reason
    when 7
      phase_seven_reason
    when 8
      phase_eight_reason
    when 9
      phase_nine_reason
    else
      { status: :red, reason: "Unknown phase", to_green: "Invalid phase number" }
    end
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

  attr_reader :title

  # Helper method to compare semantic versions
  def semantic_version_gte?(version_string, target_version)
    return false unless version_string.present? && version_string.is_a?(String)
    return false unless version_string.match?(/\A\d+\.\d+\.\d+\z/)
    
    major, minor, patch = version_string.split('.').map(&:to_i)
    target_major, target_minor, target_patch = target_version.split('.').map(&:to_i)
    
    return true if major > target_major
    return false if major < target_major
    return true if minor > target_minor
    return false if minor < target_minor
    patch >= target_patch
  end

  # Phase 1 Health: Check positions, required assignments, and assignment outcomes
  def phase_one_health
    positions = title.positions.to_a
    return :red if positions.empty?

    positions_with_required = positions.count { |p| p.position_assignments.where(assignment_type: 'required').exists? }
    percentage_with_required = positions.length > 0 ? (positions_with_required.to_f / positions.length) * 100 : 0.0

    if percentage_with_required < 34
      return :red
    end

    # Check positions with required assignments that have outcomes
    positions_with_outcomes = positions.count do |position|
      required_assignments = position.position_assignments.where(assignment_type: 'required').includes(:assignment)
      required_assignments.any? { |pa| pa.assignment.assignment_outcomes.exists? }
    end
    percentage_with_outcomes = positions.length > 0 ? (positions_with_outcomes.to_f / positions.length) * 100 : 0.0

    if percentage_with_outcomes >= 68
      :green
    else
      :yellow
    end
  end

  def phase_one_reason
    health = phase_one_health
    positions = title.positions.to_a
    
    case health
    when :red
      positions_with_required = positions.count { |p| p.position_assignments.where(assignment_type: 'required').exists? }
      percentage = positions.empty? ? 0 : (positions_with_required.to_f / positions.length) * 100
      {
        status: :red,
        reason: "#{percentage.round(1)}% of positions have at least one required assignment",
        to_green: "Ensure at least 34% of positions have at least one required assignment, and at least 68% have required assignments with outcomes defined"
      }
    when :yellow
      positions_with_outcomes = positions.count do |position|
        required_assignments = position.position_assignments.where(assignment_type: 'required').includes(:assignment)
        required_assignments.any? { |pa| pa.assignment.assignment_outcomes.exists? }
      end
      percentage = positions.empty? ? 0.0 : (positions_with_outcomes.to_f / positions.length) * 100
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of positions have required assignments with outcomes defined",
        to_green: "Ensure at least 68% of positions have at least one required assignment where the assignment has at least one outcome defined"
      }
    when :green
      {
        status: :green,
        reason: "At least 68% of positions have required assignments with outcomes defined",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 2 Health: Semantic version >= 1.0.0
  def phase_two_health
    positions = title.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = positions.length + assignments.length
    return :red if total_entities == 0

    entities_at_1_0_0 = 0
    entities_at_1_0_0 += positions.count { |p| semantic_version_gte?(p.semantic_version, '1.0.0') }
    entities_at_1_0_0 += assignments.count { |a| semantic_version_gte?(a.semantic_version, '1.0.0') }

    percentage = (entities_at_1_0_0.to_f / total_entities) * 100

    if percentage < 34
      :red
    elsif percentage >= 68
      :green
    else
      :yellow
    end
  end

  def phase_two_reason
    health = phase_two_health
    positions = title.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = positions.length + assignments.length
    entities_at_1_0_0 = 0
    entities_at_1_0_0 += positions.count { |p| semantic_version_gte?(p.semantic_version, '1.0.0') }
    entities_at_1_0_0 += assignments.count { |a| semantic_version_gte?(a.semantic_version, '1.0.0') }
    percentage = total_entities == 0 ? 0 : (entities_at_1_0_0.to_f / total_entities) * 100

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage.round(1)}% of positions and assignments are >= 1.0.0",
        to_green: "Ensure at least 34% of all positions and assignments are >= 1.0.0"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of positions and assignments are >= 1.0.0",
        to_green: "Ensure at least 68% of all positions and assignments are >= 1.0.0"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage.round(1)}% of positions and assignments are >= 1.0.0",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 3 Health: Employment tenures and check-ins
  def phase_three_health
    position_ids = title.positions.pluck(:id)
    return :red if position_ids.empty?

    # Check for employment tenures
    tenures = EmploymentTenure
      .where(position_id: position_ids)
      .includes(:position, :position_check_ins)

    # Check if any check-ins exist at all (not just recent)
    any_check_ins_exist = PositionCheckIn
      .joins(:employment_tenure)
      .where(employment_tenures: { position_id: position_ids })
      .exists?

    # Check for employment tenures longer than a day
    tenures_longer_than_day = tenures.select do |tenure|
      end_date = tenure.ended_at || Date.current
      (end_date - tenure.started_at).to_i > 1
    end

    # Red: No tenures longer than a day AND no check-ins exist
    return :red if tenures_longer_than_day.empty? && !any_check_ins_exist

    # If no tenures longer than a day, but check-ins exist, still red (need tenure >1 day)
    return :red if tenures_longer_than_day.empty?

    # Check for check-ins in the past year
    one_year_ago_date = 1.year.ago.to_date
    one_year_ago_datetime = 1.year.ago
    has_recent_check_in = tenures_longer_than_day.any? do |tenure|
      tenure.position_check_ins.any? do |check_in|
        check_in.check_in_started_on >= one_year_ago_date || 
        (check_in.official_check_in_completed_at && check_in.official_check_in_completed_at >= one_year_ago_datetime)
      end
    end

    has_recent_check_in ? :green : :yellow
  end

  def phase_three_reason
    health = phase_three_health
    position_ids = title.positions.pluck(:id)

    case health
    when :red
      {
        status: :red,
        reason: "No positions have employment tenures longer than a day, or no check-ins exist",
        to_green: "Create employment tenures longer than a day and complete at least one position check-in within the past year"
      }
    when :yellow
      {
        status: :yellow,
        reason: "At least one employment tenure longer than a day exists, but no check-ins in the past year",
        to_green: "Complete at least one position check-in within the past year for a tenure longer than a day"
      }
    when :green
      {
        status: :green,
        reason: "At least one employment tenure longer than a day exists with check-ins in the past year",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 4 Health: Assignments with abilities
  def phase_four_health
    required_assignment_ids = PositionAssignment
      .joins(:position)
      .where(positions: { title_id: title.id })
      .where(assignment_type: 'required')
      .distinct
      .pluck(:assignment_id)

    return :red if required_assignment_ids.empty?

    assignments_with_abilities = AssignmentAbility
      .where(assignment_id: required_assignment_ids)
      .distinct
      .pluck(:assignment_id)
      .uniq

    percentage = required_assignment_ids.length > 0 ? (assignments_with_abilities.length.to_f / required_assignment_ids.length) * 100 : 0.0

    if percentage < 34
      :red
    elsif percentage >= 68
      :green
    else
      :yellow
    end
  end

  def phase_four_reason
    health = phase_four_health
    required_assignment_ids = PositionAssignment
      .joins(:position)
      .where(positions: { title_id: title.id })
      .where(assignment_type: 'required')
      .distinct
      .pluck(:assignment_id)

    if required_assignment_ids.empty?
      return {
        status: :red,
        reason: "No required assignments exist",
        to_green: "Create required assignments first, then ensure at least 34% have at least one ability"
      }
    end

    assignments_with_abilities = AssignmentAbility
      .where(assignment_id: required_assignment_ids)
      .distinct
      .pluck(:assignment_id)
      .uniq

    percentage = required_assignment_ids.length > 0 ? (assignments_with_abilities.length.to_f / required_assignment_ids.length) * 100 : 0.0

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage.round(1)}% of assignments have at least one ability",
        to_green: "Ensure at least 34% of assignments have at least one ability"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of assignments have at least one ability",
        to_green: "Ensure at least 68% of assignments have at least one ability"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage.round(1)}% of assignments have at least one ability",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 5 Health: Required abilities with >= 3 milestones
  def phase_five_health
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    return :red if abilities.empty?

    abilities_with_3_milestones = abilities.count do |ability|
      ability.milestone_1_description.present? &&
      ability.milestone_2_description.present? &&
      ability.milestone_3_description.present?
    end

    percentage = abilities.length > 0 ? (abilities_with_3_milestones.to_f / abilities.length) * 100 : 0.0

    if percentage < 34
      :red
    elsif percentage >= 68
      :green
    else
      :yellow
    end
  end

  def phase_five_reason
    health = phase_five_health
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    if abilities.empty?
      return {
        status: :red,
        reason: "No required abilities exist",
        to_green: "Create required abilities first, then ensure at least 34% have at least 3 milestones defined"
      }
    end

    abilities_with_3_milestones = abilities.count do |ability|
      ability.milestone_1_description.present? &&
      ability.milestone_2_description.present? &&
      ability.milestone_3_description.present?
    end

    percentage = abilities.length > 0 ? (abilities_with_3_milestones.to_f / abilities.length) * 100 : 0.0

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage.round(1)}% of required abilities have at least 3 milestones",
        to_green: "Ensure at least 34% of required abilities have at least 3 milestones defined"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of required abilities have at least 3 milestones",
        to_green: "Ensure at least 68% of required abilities have at least 3 milestones defined"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage.round(1)}% of required abilities have at least 3 milestones",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 6 Health: Required abilities with teammate milestones
  def phase_six_health
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    return :red if abilities.empty?

    abilities_with_milestones = abilities.count { |ability| ability.teammate_milestones.exists? }
    percentage = abilities.length > 0 ? (abilities_with_milestones.to_f / abilities.length) * 100 : 0.0

    if percentage < 34
      :red
    elsif percentage >= 68
      :green
    else
      :yellow
    end
  end

  def phase_six_reason
    health = phase_six_health
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    if abilities.empty?
      return {
        status: :red,
        reason: "No required abilities exist",
        to_green: "Create required abilities first, then ensure at least 34% have teammate milestones awarded"
      }
    end

    abilities_with_milestones = abilities.count { |ability| ability.teammate_milestones.exists? }
    percentage = abilities.length > 0 ? (abilities_with_milestones.to_f / abilities.length) * 100 : 0.0

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage.round(1)}% of required abilities have had a teammate milestone awarded",
        to_green: "Ensure at least 34% of required abilities have had a teammate milestone awarded"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of required abilities have had a teammate milestone awarded",
        to_green: "Ensure at least 68% of required abilities have had a teammate milestone awarded"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage.round(1)}% of required abilities have had a teammate milestone awarded",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 7 Health: Positions with eligibility requirements summaries
  def phase_seven_health
    positions = title.positions.to_a
    return :red if positions.empty?

    positions_with_summaries = positions.count { |p| p.eligibility_requirements_summary.present? }
    percentage = positions.length > 0 ? (positions_with_summaries.to_f / positions.length) * 100 : 0.0

    if percentage == 0
      :red
    elsif percentage >= 68
      :green
    elsif percentage > 34
      :yellow
    else
      :red
    end
  end

  def phase_seven_reason
    health = phase_seven_health
    positions = title.positions.to_a
    positions_with_summaries = positions.count { |p| p.eligibility_requirements_summary.present? }
    percentage = positions.length > 0 ? (positions_with_summaries.to_f / positions.length) * 100 : 0.0

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage.round(1)}% of positions have eligibility requirements summaries",
        to_green: "Ensure more than 34% of positions have eligibility requirements summaries"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of positions have eligibility requirements summaries",
        to_green: "Ensure at least 68% of positions have eligibility requirements summaries"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage.round(1)}% of positions have eligibility requirements summaries",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 8 Health: Continuous improvement (created/updated dates)
  def phase_eight_health
    positions = title.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = positions.length + assignments.length + abilities.length
    return :red if total_entities == 0

    six_months_ago = 6.months.ago
    three_months_ago = 3.months.ago
    one_week = 7.days

    # Count entities created in last 6 months
    created_recently = 0
    created_recently += positions.count { |p| p.created_at >= six_months_ago }
    created_recently += assignments.count { |a| a.created_at >= six_months_ago }
    created_recently += abilities.count { |a| a.created_at >= six_months_ago }
    percentage_created = (created_recently.to_f / total_entities) * 100

    # Count entities updated in last 3 months
    updated_recently_3m = 0
    updated_recently_3m += positions.count { |p| p.updated_at >= three_months_ago }
    updated_recently_3m += assignments.count { |a| a.updated_at >= three_months_ago }
    updated_recently_3m += abilities.count { |a| a.updated_at >= three_months_ago }
    percentage_updated_3m = (updated_recently_3m.to_f / total_entities) * 100

    # Count entities updated in last 6 months with >1 week difference
    updated_recently_6m = 0
    all_entities = positions + assignments + abilities
    updated_recently_6m = all_entities.count do |entity|
      entity.updated_at >= six_months_ago &&
      (entity.updated_at - entity.created_at) > one_week
    end
    percentage_updated_6m = (updated_recently_6m.to_f / total_entities) * 100

    # Red: <68% created in last 6 months AND <34% updated in last 3 months
    if percentage_created < 68 && percentage_updated_3m < 34
      return :red
    end

    # Yellow: >=68% created in last 6 months AND <34% updated in last 3 months
    if percentage_created >= 68 && percentage_updated_3m < 34
      return :yellow
    end

    # Green: >34% updated in last 6 months with >1 week difference
    if percentage_updated_6m > 34
      :green
    else
      :yellow
    end
  end

  def phase_eight_reason
    health = phase_eight_health
    positions = title.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = positions.length + assignments.length + abilities.length
    six_months_ago = 6.months.ago
    three_months_ago = 3.months.ago
    one_week = 7.days

    created_recently = 0
    created_recently += positions.count { |p| p.created_at >= six_months_ago }
    created_recently += assignments.count { |a| a.created_at >= six_months_ago }
    created_recently += abilities.count { |a| a.created_at >= six_months_ago }
    percentage_created = total_entities == 0 ? 0 : (created_recently.to_f / total_entities) * 100

    updated_recently_3m = 0
    updated_recently_3m += positions.count { |p| p.updated_at >= three_months_ago }
    updated_recently_3m += assignments.count { |a| a.updated_at >= three_months_ago }
    updated_recently_3m += abilities.count { |a| a.updated_at >= three_months_ago }
    percentage_updated_3m = total_entities == 0 ? 0 : (updated_recently_3m.to_f / total_entities) * 100

    all_entities = positions + assignments + abilities
    updated_recently_6m = all_entities.count do |entity|
      entity.updated_at >= six_months_ago &&
      (entity.updated_at - entity.created_at) > one_week
    end
    percentage_updated_6m = total_entities == 0 ? 0 : (updated_recently_6m.to_f / total_entities) * 100

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage_created.round(1)}% created in last 6 months and #{percentage_updated_3m.round(1)}% updated in last 3 months",
        to_green: "Ensure at least 68% were created in last 6 months OR at least 34% were updated in last 3 months, and eventually >34% updated in last 6 months with >1 week difference from creation"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage_created.round(1)}% created in last 6 months but only #{percentage_updated_3m.round(1)}% updated in last 3 months",
        to_green: "Ensure more than 34% of entities were updated in the last 6 months (with >1 week difference between created_at and updated_at)"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage_updated_6m.round(1)}% of entities updated in last 6 months with meaningful changes (>1 week difference)",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 9 Health: Observation ratings in past year
  def phase_nine_health
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = assignments.length + abilities.length
    return :red if total_entities == 0

    one_year_ago = 1.year.ago

    # Get entities with observation ratings in past year
    assignment_ids = assignments.map(&:id)
    ability_ids = abilities.map(&:id)

    observed_assignments = ObservationRating
      .where(rateable_type: 'Assignment', rateable_id: assignment_ids)
      .where('created_at >= ?', one_year_ago)
      .distinct
      .pluck(:rateable_id)
      .uniq

    observed_abilities = ObservationRating
      .where(rateable_type: 'Ability', rateable_id: ability_ids)
      .where('created_at >= ?', one_year_ago)
      .distinct
      .pluck(:rateable_id)
      .uniq

    observed_count = observed_assignments.length + observed_abilities.length
    percentage = (observed_count.to_f / total_entities) * 100

    if percentage < 34
      :red
    elsif percentage >= 68
      :green
    else
      :yellow
    end
  end

  def phase_nine_reason
    health = phase_nine_health
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a

    total_entities = assignments.length + abilities.length
    if total_entities == 0
      return {
        status: :red,
        reason: "No abilities or assignments exist",
        to_green: "Create abilities and assignments first, then ensure at least 34% have observation ratings in the past year"
      }
    end

    one_year_ago = 1.year.ago
    assignment_ids = assignments.map(&:id)
    ability_ids = abilities.map(&:id)

    observed_assignments = ObservationRating
      .where(rateable_type: 'Assignment', rateable_id: assignment_ids)
      .where('created_at >= ?', one_year_ago)
      .distinct
      .pluck(:rateable_id)
      .uniq

    observed_abilities = ObservationRating
      .where(rateable_type: 'Ability', rateable_id: ability_ids)
      .where('created_at >= ?', one_year_ago)
      .distinct
      .pluck(:rateable_id)
      .uniq

    observed_count = observed_assignments.length + observed_abilities.length
    percentage = (observed_count.to_f / total_entities) * 100

    case health
    when :red
      {
        status: :red,
        reason: "#{percentage.round(1)}% of abilities and assignments have been part of an observation rating in the past year",
        to_green: "Ensure at least 34% of abilities and assignments have been part of an observation rating in the past year"
      }
    when :yellow
      {
        status: :yellow,
        reason: "#{percentage.round(1)}% of abilities and assignments have been part of an observation rating in the past year",
        to_green: "Ensure at least 68% of abilities and assignments have been part of an observation rating in the past year"
      }
    when :green
      {
        status: :green,
        reason: "#{percentage.round(1)}% of abilities and assignments have been part of an observation rating in the past year",
        to_green: "Maintain this healthy state"
      }
    end
  end

  # Phase 1: At least one position has ≥1 required assignment
  def phase_one_met?
    title.positions.joins(:position_assignments)
                  .where(position_assignments: { assignment_type: 'required' })
                  .exists?
  end

  # Phase 2: All positions have ≥1 required assignment
  def phase_two_met?
    positions = title.positions
    return false if positions.empty?
    
    positions.all? do |position|
      position.position_assignments.where(assignment_type: 'required').exists?
    end
  end

  # Phase 3: At least one position has employment_tenure AND there exists ≥1 AssignmentCheckIn for required assignments
  def phase_three_met?
    # Check if any position has an employment tenure
    position_ids = title.positions.pluck(:id)
    return false if position_ids.empty?

    positions_with_tenures = EmploymentTenure
      .where(position_id: position_ids)
      .active  # Only count active employment tenures
      .distinct
      .pluck(:position_id)

    return false if positions_with_tenures.empty?

    # Get all required assignment IDs for positions with tenures
    required_assignment_ids = PositionAssignment
      .where(position_id: positions_with_tenures, assignment_type: 'required')
      .pluck(:assignment_id)
      .uniq

    return false if required_assignment_ids.empty?

    # Check if there's at least one AssignmentCheckIn for any of these assignments
    # We need to find teammates associated with employment tenures for these positions
    employment_tenures = EmploymentTenure
      .where(position_id: positions_with_tenures)
      .active  # Only count active employment tenures
      .includes(:company_teammate)

    teammate_ids = employment_tenures.map(&:company_teammate).compact.uniq.map(&:id)

    return false if teammate_ids.empty?

    # Check for AssignmentCheckIns for these teammates and required assignments
    AssignmentCheckIn
      .where(teammate_id: teammate_ids, assignment_id: required_assignment_ids)
      .exists?
  end

  # Phase 4: All required assignments have ≥1 AssignmentAbility
  def phase_four_met?
    # Get all required assignments for positions in this title
    required_assignment_ids = PositionAssignment
      .joins(:position)
      .where(positions: { title_id: title.id })
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
      .where(positions: { title_id: title.id })
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
      .where(positions: { title_id: title.id })
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
    positions = title.positions
    return false if positions.empty?

    positions.all? do |position|
      position.eligibility_requirements_summary.present?
    end
  end

  # Phase 8: ≥5% of Abilities/Assignments/Positions updated in last 6 months
  def phase_eight_met?
    six_months_ago = 6.months.ago

    # Get all related entities
    positions = title.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
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
    positions = title.positions.to_a
    assignments = Assignment
      .joins(position_assignments: :position)
      .where(positions: { title_id: title.id })
      .where(position_assignments: { assignment_type: 'required' })
      .distinct
      .to_a
    abilities = Ability
      .joins(assignment_abilities: { assignment: { position_assignments: :position } })
      .where(positions: { title_id: title.id })
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
