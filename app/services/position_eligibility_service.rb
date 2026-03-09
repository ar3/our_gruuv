class PositionEligibilityService
  ASSIGNMENT_RATING_LEVELS = {
    'working_to_meet' => 1,
    'meeting' => 2,
    'exceeding' => 3
  }.freeze

  # Default eligibility requirement values when none are set for a position.
  # Used when viewing the eligibility requirements page and when pre-populating the manage form.
  DEFAULT_ELIGIBILITY_REQUIREMENTS = {
    'company_aspirational_values_check_in_requirements' => {
      'minimum_months_at_or_above_rating_criteria' => 3,
      'minimum_percentage_of_aspirational_values_meeting' => 80,
      'minimum_percentage_of_aspirational_values_exceeding' => 0
    }.freeze,
    'required_assignment_check_in_requirements' => {
      'minimum_months_at_or_above_rating_criteria' => 3,
      'minimum_percentage_of_assignments_meeting' => 80,
      'minimum_percentage_of_assignments_exceeding' => 0
    }.freeze,
    'unique_to_you_assignment_check_in_requirements' => {
      'minimum_months_at_or_above_rating_criteria' => 0,
      'minimum_percentage_of_assignments_meeting' => 0,
      'minimum_percentage_of_assignments_exceeding' => 0
    }.freeze,
    'position_check_in_requirements' => {
      'minimum_rating' => 2,
      'minimum_months_at_or_above_rating_criteria' => 3
    }.freeze,
    'mileage_requirements' => {
      'threshold_type' => 'percentage',
      'threshold_value' => 20
    }.freeze
  }.freeze

  def initialize(mileage_service: MilestoneMileageService.new)
    @mileage_service = mileage_service
  end

  def check_eligibility(teammate, position)
    requirements = parse_requirements(position)
    checks = []

    checks << check_milestone_requirements(teammate, position, requirements[:milestone_requirements])
    checks << check_mileage_requirements(teammate, position, requirements[:mileage_requirements])
    checks << check_position_check_in_requirements(teammate, requirements[:position_check_in_requirements])
    checks << check_required_assignment_check_ins(teammate, position, requirements[:required_assignment_check_in_requirements])
    checks << check_unique_to_you_assignment_check_ins(teammate, position, requirements[:unique_to_you_assignment_check_in_requirements])
    checks << check_company_aspirational_values_check_ins(teammate, position, requirements[:company_aspirational_values_check_in_requirements])

    configured_checks = checks.select { |check| check[:status] != :not_configured }
    overall_eligible = configured_checks.any? && configured_checks.all? { |check| check[:status] == :passed || check[:status] == :not_applicable }

    {
      teammate: teammate,
      position: position,
      overall_eligible: overall_eligible,
      checks: checks
    }
  end

  # Returns eligibility data hash with default values applied wherever a section is blank.
  # Used for parsing requirements in check_eligibility and for pre-populating the manage form.
  def self.eligibility_data_with_defaults(raw)
    raw = raw.to_h if raw.respond_to?(:to_h)
    result = raw.stringify_keys
    DEFAULT_ELIGIBILITY_REQUIREMENTS.each do |section_key, default_section|
      existing = result[section_key]
      result[section_key] = default_section.dup if existing.blank?
    end
    result
  end

  def parse_requirements(position)
    raw = position&.eligibility_requirements_explicit || {}
    raw = raw.to_h if raw.respond_to?(:to_h)
    with_defaults = self.class.eligibility_data_with_defaults(raw)

    {
      milestone_requirements: with_defaults['milestone_requirements'] || [],
      mileage_requirements: with_defaults['mileage_requirements'] || {},
      position_check_in_requirements: with_defaults['position_check_in_requirements'] || {},
      required_assignment_check_in_requirements: with_defaults['required_assignment_check_in_requirements'] || {},
      unique_to_you_assignment_check_in_requirements: with_defaults['unique_to_you_assignment_check_in_requirements'] || {},
      company_aspirational_values_check_in_requirements: with_defaults['company_aspirational_values_check_in_requirements'] || {}
    }
  end

  def check_milestone_requirements(teammate, position, requirements)
    requirements = requirements.presence || derived_milestone_requirements(position)
    return not_configured_check(:milestone_requirements) if requirements.blank?

    results = requirements.map do |requirement|
      ability_id = requirement['ability_id'] || requirement[:ability_id]
      minimum_level = requirement['minimum_milestone_level'] || requirement[:minimum_milestone_level]
      highest_level = TeammateMilestone.where(company_teammate: teammate, ability_id: ability_id).maximum(:milestone_level)

      {
        ability_id: ability_id,
        minimum_milestone_level: minimum_level,
        highest_milestone_level: highest_level,
        passed: highest_level.present? && highest_level >= minimum_level.to_i
      }
    end

    {
      key: :milestone_requirements,
      label: 'Milestone Requirements',
      status: results.all? { |result| result[:passed] } ? :passed : :failed,
      details: {
        total_requirements: results.length,
        met_requirements: results.count { |result| result[:passed] },
        requirements: results
      }
    }
  end

  def check_mileage_requirements(teammate, position, requirements)
    effective_min, base_from_milestones, threshold_type, threshold_value = resolve_mileage_threshold(position, requirements)
    return not_configured_check(:mileage_requirements) if effective_min.nil?

    total_points = @mileage_service.total_mileage_for(teammate)
    passed = total_points >= effective_min
    missing_points = [effective_min - total_points, 0].max

    details = {
      minimum_mileage_points: effective_min,
      total_mileage_points: total_points,
      next_steps: passed ? nil : "Needs #{missing_points} more mileage points"
    }
    if threshold_type == 'percentage'
      details[:threshold_type] = 'percentage'
      details[:threshold_value] = threshold_value
      details[:minimum_required_from_milestones] = base_from_milestones
    end

    {
      key: :mileage_requirements,
      label: 'Milestone Mileage',
      status: passed ? :passed : :failed,
      details: details
    }
  end

  # Returns [effective_minimum, base_from_milestones, threshold_type, threshold_value].
  # effective_minimum is nil when not configured. For percentage, base_from_milestones is the required-milestone sum.
  def resolve_mileage_threshold(position, requirements)
    threshold_type = requirements['threshold_type'] || requirements[:threshold_type]
    threshold_value = requirements['threshold_value'] || requirements[:threshold_value]
    legacy_points = requirements['minimum_mileage_points'] || requirements[:minimum_mileage_points]

    if threshold_type == 'percentage'
      return [nil, nil, nil, nil] if threshold_value.blank?
      base = @mileage_service.minimum_required_for_position(position)
      effective = (base * (100 + threshold_value.to_i) / 100).round
      [effective, base, 'percentage', threshold_value.to_i]
    elsif threshold_type == 'absolute' || legacy_points.present?
      points = (threshold_type == 'absolute' ? threshold_value : legacy_points)
      return [nil, nil, nil, nil] if points.blank?
      [points.to_i, nil, threshold_type || (legacy_points.present? ? nil : 'absolute'), points.to_i]
    else
      [nil, nil, nil, nil]
    end
  end

  def check_position_check_in_requirements(teammate, requirements)
    minimum_rating = requirements['minimum_rating'] || requirements[:minimum_rating]
    minimum_months = requirements['minimum_months_at_or_above_rating_criteria'] || requirements[:minimum_months_at_or_above_rating_criteria]
    return not_configured_check(:position_check_in_requirements) if minimum_rating.blank? || minimum_months.blank?

    qualifying_months = months_with_position_check_in_rating(teammate, minimum_rating.to_i, minimum_months.to_i)
    passed = qualifying_months >= minimum_months.to_i
    remaining_months = [minimum_months.to_i - qualifying_months, 0].max

    {
      key: :position_check_in_requirements,
      label: 'Position Check-Ins',
      status: passed ? :passed : :failed,
      details: {
        minimum_rating: minimum_rating.to_i,
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        qualifying_months: qualifying_months,
        next_steps: passed ? nil : "Needs #{remaining_months} more months at or above rating"
      }
    }
  end

  def check_required_assignment_check_ins(teammate, position, requirements)
    check_assignment_group(
      key: :required_assignment_check_in_requirements,
      label: 'Required Assignment Check-Ins',
      assignments: position.required_assignments.map(&:assignment),
      teammate: teammate,
      requirements: requirements
    )
  end

  def check_unique_to_you_assignment_check_ins(teammate, position, requirements)
    assignments = unique_to_you_assignments(teammate, position)
    min_pct_meeting = requirements['minimum_percentage_of_assignments_meeting'] || requirements[:minimum_percentage_of_assignments_meeting]
    min_pct_meeting = min_pct_meeting.to_f if min_pct_meeting.present?
    # When minimum meeting expectation is 0%, nil, or empty and there are no assignments -> not applicable (card still shown)
    if assignments.length.zero? && (min_pct_meeting.blank? || min_pct_meeting == 0.0)
      return {
        key: :unique_to_you_assignment_check_in_requirements,
        label: 'Unique-to-You Assignment Check-Ins',
        status: :not_applicable,
        details: { minimum_percentage_meeting: min_pct_meeting, total_assignments: 0 }
      }
    end
    check_assignment_group(
      key: :unique_to_you_assignment_check_in_requirements,
      label: 'Unique-to-You Assignment Check-Ins',
      assignments: assignments,
      teammate: teammate,
      requirements: requirements
    )
  end

  def check_company_aspirational_values_check_ins(teammate, position, requirements)
    company = position.company.root_company || position.company
    aspirations = Aspiration.within_hierarchy(company).ordered

    check_aspiration_group(
      key: :company_aspirational_values_check_in_requirements,
      label: 'Company Aspirational Values Check-Ins',
      aspirations: aspirations,
      teammate: teammate,
      requirements: requirements
    )
  end

  private

  def not_configured_check(key)
    {
      key: key,
      label: key.to_s.humanize,
      status: :not_configured,
      details: {}
    }
  end

  def derived_milestone_requirements(position)
    return [] unless position

    from_assignments = position.required_assignments.flat_map do |position_assignment|
      position_assignment.assignment.assignment_abilities.map do |assignment_ability|
        {
          ability_id: assignment_ability.ability_id,
          minimum_milestone_level: assignment_ability.milestone_level
        }
      end
    end

    from_position_direct = position.position_abilities.map do |position_ability|
      {
        ability_id: position_ability.ability_id,
        minimum_milestone_level: position_ability.milestone_level
      }
    end

    from_assignments + from_position_direct
  end

  def unique_to_you_assignments(teammate, position)
    return [] unless teammate && position

    required_assignment_ids = position.required_assignments.pluck(:assignment_id)
    teammate.assignment_tenures.active
            .where.not(assignment_id: required_assignment_ids)
            .includes(:assignment)
            .map(&:assignment)
            .uniq
  end

  def months_with_position_check_in_rating(teammate, minimum_rating, minimum_months)
    cutoff_date = minimum_months.months.ago.to_date
    check_ins = PositionCheckIn.closed
                               .where(company_teammate: teammate)
                               .where('check_in_started_on >= ?', cutoff_date)

    qualifying_check_ins = check_ins.select do |check_in|
      check_in.official_rating.present? && check_in.official_rating >= minimum_rating
    end

    qualifying_check_ins
      .group_by { |check_in| check_in.check_in_started_on.beginning_of_month }
      .count
  end

  def check_assignment_group(key:, label:, assignments:, teammate:, requirements:)
    minimum_months = requirements['minimum_months_at_or_above_rating_criteria'] || requirements[:minimum_months_at_or_above_rating_criteria]
    min_pct_meeting = requirements['minimum_percentage_of_assignments_meeting'] || requirements[:minimum_percentage_of_assignments_meeting]
    min_pct_exceeding = requirements['minimum_percentage_of_assignments_exceeding'] || requirements[:minimum_percentage_of_assignments_exceeding]
    min_pct_meeting = min_pct_meeting.to_f if min_pct_meeting.present?
    min_pct_exceeding = min_pct_exceeding.to_f if min_pct_exceeding.present?
    return not_configured_check(key) if minimum_months.blank? || (min_pct_meeting.blank? && min_pct_exceeding.blank?)

    total_assignments = assignments.length
    if total_assignments.zero?
      # Requirements are configured but there are no assignments to evaluate -> failed
      details = {
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        minimum_percentage_meeting: min_pct_meeting,
        minimum_percentage_exceeding: min_pct_exceeding,
        total_assignments: 0,
        qualifying_meeting: 0,
        qualifying_exceeding: 0,
        qualifying_percentage_meeting: 0.0,
        qualifying_percentage_exceeding: 0.0
      }
      details[:minimum_percentage] = min_pct_exceeding.presence || min_pct_meeting
      details[:minimum_rating] = min_pct_exceeding.present? ? 'exceeding' : 'meeting'
      return {
        key: key,
        label: label,
        status: :failed,
        details: details.merge(next_steps: "Needs more assignments meeting criteria")
      }
    end

    qualifying_meeting = assignments.count { |a| assignment_meets_check_in_requirement?(teammate, a, 'meeting', minimum_months.to_i) }
    qualifying_exceeding = assignments.count { |a| assignment_meets_check_in_requirement?(teammate, a, 'exceeding', minimum_months.to_i) }
    pct_meeting = (qualifying_meeting.to_f / total_assignments) * 100.0
    pct_exceeding = (qualifying_exceeding.to_f / total_assignments) * 100.0

    passed_meeting = min_pct_meeting.blank? || pct_meeting >= min_pct_meeting
    passed_exceeding = min_pct_exceeding.blank? || pct_exceeding >= min_pct_exceeding
    passed = passed_meeting && passed_exceeding

    details = {
      minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
      minimum_percentage_meeting: min_pct_meeting,
      minimum_percentage_exceeding: min_pct_exceeding,
      total_assignments: total_assignments,
      qualifying_meeting: qualifying_meeting,
      qualifying_exceeding: qualifying_exceeding,
      qualifying_percentage_meeting: pct_meeting,
      qualifying_percentage_exceeding: pct_exceeding
    }
    details[:minimum_percentage] = min_pct_exceeding.presence || min_pct_meeting
    details[:minimum_rating] = min_pct_exceeding.present? ? 'exceeding' : 'meeting'

    {
      key: key,
      label: label,
      status: passed ? :passed : :failed,
      details: details.merge(
        next_steps: passed ? nil : "Needs more assignments meeting criteria"
      )
    }
  end

  def check_aspiration_group(key:, label:, aspirations:, teammate:, requirements:)
    minimum_months = requirements['minimum_months_at_or_above_rating_criteria'] || requirements[:minimum_months_at_or_above_rating_criteria]
    min_pct_meeting = requirements['minimum_percentage_of_aspirational_values_meeting'] || requirements[:minimum_percentage_of_aspirational_values_meeting]
    min_pct_exceeding = requirements['minimum_percentage_of_aspirational_values_exceeding'] || requirements[:minimum_percentage_of_aspirational_values_exceeding]
    min_pct_meeting = min_pct_meeting.to_f if min_pct_meeting.present?
    min_pct_exceeding = min_pct_exceeding.to_f if min_pct_exceeding.present?
    return not_configured_check(key) if minimum_months.blank? || (min_pct_meeting.blank? && min_pct_exceeding.blank?)

    total_aspirations = aspirations.length
    if total_aspirations.zero?
      details = {
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        minimum_percentage_meeting: min_pct_meeting,
        minimum_percentage_exceeding: min_pct_exceeding,
        total_aspirations: 0,
        qualifying_meeting: 0,
        qualifying_exceeding: 0,
        qualifying_percentage_meeting: 0.0,
        qualifying_percentage_exceeding: 0.0
      }
      details[:minimum_percentage] = min_pct_exceeding.presence || min_pct_meeting
      details[:minimum_rating] = min_pct_exceeding.present? ? 'exceeding' : 'meeting'
      return {
        key: key,
        label: label,
        status: :failed,
        details: details.merge(next_steps: "Needs more values meeting criteria")
      }
    end

    qualifying_meeting = aspirations.count { |a| aspiration_meets_check_in_requirement?(teammate, a, 'meeting', minimum_months.to_i) }
    qualifying_exceeding = aspirations.count { |a| aspiration_meets_check_in_requirement?(teammate, a, 'exceeding', minimum_months.to_i) }
    pct_meeting = (qualifying_meeting.to_f / total_aspirations) * 100.0
    pct_exceeding = (qualifying_exceeding.to_f / total_aspirations) * 100.0

    passed_meeting = min_pct_meeting.blank? || pct_meeting >= min_pct_meeting
    passed_exceeding = min_pct_exceeding.blank? || pct_exceeding >= min_pct_exceeding
    passed = passed_meeting && passed_exceeding

    details = {
      minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
      minimum_percentage_meeting: min_pct_meeting,
      minimum_percentage_exceeding: min_pct_exceeding,
      total_aspirations: total_aspirations,
      qualifying_meeting: qualifying_meeting,
      qualifying_exceeding: qualifying_exceeding,
      qualifying_percentage_meeting: pct_meeting,
      qualifying_percentage_exceeding: pct_exceeding
    }
    details[:minimum_percentage] = min_pct_exceeding.presence || min_pct_meeting
    details[:minimum_rating] = min_pct_exceeding.present? ? 'exceeding' : 'meeting'

    {
      key: key,
      label: label,
      status: passed ? :passed : :failed,
      details: details.merge(
        next_steps: passed ? nil : "Needs more values meeting criteria"
      )
    }
  end

  def assignment_meets_check_in_requirement?(teammate, assignment, minimum_rating, minimum_months)
    cutoff_date = minimum_months.months.ago.to_date
    check_ins = AssignmentCheckIn.closed
                                 .where(company_teammate: teammate, assignment: assignment)
                                 .where('check_in_started_on >= ?', cutoff_date)

    qualifying_check_ins = check_ins.select do |check_in|
      rating_meets_threshold?(check_in.official_rating, minimum_rating)
    end

    qualifying_check_ins
      .group_by { |check_in| check_in.check_in_started_on.beginning_of_month }
      .count >= minimum_months
  end

  def aspiration_meets_check_in_requirement?(teammate, aspiration, minimum_rating, minimum_months)
    cutoff_date = minimum_months.months.ago.to_date
    check_ins = AspirationCheckIn.closed
                                 .where(company_teammate: teammate, aspiration: aspiration)
                                 .where('check_in_started_on >= ?', cutoff_date)

    qualifying_check_ins = check_ins.select do |check_in|
      rating_meets_threshold?(check_in.official_rating, minimum_rating)
    end

    qualifying_check_ins
      .group_by { |check_in| check_in.check_in_started_on.beginning_of_month }
      .count >= minimum_months
  end

  def rating_meets_threshold?(rating, minimum_rating)
    return false if rating.blank?

    rating_level = ASSIGNMENT_RATING_LEVELS[rating.to_s]
    minimum_level = ASSIGNMENT_RATING_LEVELS[minimum_rating.to_s]
    return false unless rating_level && minimum_level

    rating_level >= minimum_level
  end
end
