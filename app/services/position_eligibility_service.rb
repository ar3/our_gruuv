class PositionEligibilityService
  ASSIGNMENT_RATING_LEVELS = {
    'working_to_meet' => 1,
    'meeting' => 2,
    'exceeding' => 3
  }.freeze

  def initialize(mileage_service: MilestoneMileageService.new)
    @mileage_service = mileage_service
  end

  def check_eligibility(teammate, position)
    requirements = parse_requirements(position)
    checks = []

    checks << check_milestone_requirements(teammate, position, requirements[:milestone_requirements])
    checks << check_mileage_requirements(teammate, requirements[:mileage_requirements])
    checks << check_position_check_in_requirements(teammate, requirements[:position_check_in_requirements])
    checks << check_required_assignment_check_ins(teammate, position, requirements[:required_assignment_check_in_requirements])
    checks << check_unique_to_you_assignment_check_ins(teammate, position, requirements[:unique_to_you_assignment_check_in_requirements])
    checks << check_company_aspirational_values_check_ins(teammate, position, requirements[:company_aspirational_values_check_in_requirements])
    checks << check_title_department_aspirational_values_check_ins(teammate, position, requirements[:title_department_aspirational_values_check_in_requirements])

    configured_checks = checks.select { |check| check[:status] != :not_configured }
    overall_eligible = configured_checks.any? && configured_checks.all? { |check| check[:status] == :passed }

    {
      teammate: teammate,
      position: position,
      overall_eligible: overall_eligible,
      checks: checks
    }
  end

  def parse_requirements(position)
    raw = position&.eligibility_requirements_explicit || {}
    raw = raw.to_h if raw.respond_to?(:to_h)

    {
      milestone_requirements: raw['milestone_requirements'] || [],
      mileage_requirements: raw['mileage_requirements'] || {},
      position_check_in_requirements: raw['position_check_in_requirements'] || {},
      required_assignment_check_in_requirements: raw['required_assignment_check_in_requirements'] || {},
      unique_to_you_assignment_check_in_requirements: raw['unique_to_you_assignment_check_in_requirements'] || {},
      company_aspirational_values_check_in_requirements: raw['company_aspirational_values_check_in_requirements'] || {},
      title_department_aspirational_values_check_in_requirements: raw['title_department_aspirational_values_check_in_requirements'] || {}
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

  def check_mileage_requirements(teammate, requirements)
    minimum_points = requirements['minimum_mileage_points'] || requirements[:minimum_mileage_points]
    return not_configured_check(:mileage_requirements) if minimum_points.blank?

    total_points = @mileage_service.total_mileage_for(teammate)
    passed = total_points >= minimum_points.to_i
    missing_points = [minimum_points.to_i - total_points, 0].max

    {
      key: :mileage_requirements,
      label: 'Milestone Mileage',
      status: passed ? :passed : :failed,
      details: {
        minimum_mileage_points: minimum_points.to_i,
        total_mileage_points: total_points,
        next_steps: passed ? nil : "Needs #{missing_points} more mileage points"
      }
    }
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
      requirements: requirements,
      percentage_key: :minimum_percentage_of_assignments
    )
  end

  def check_unique_to_you_assignment_check_ins(teammate, position, requirements)
    check_assignment_group(
      key: :unique_to_you_assignment_check_in_requirements,
      label: 'Unique-to-You Assignment Check-Ins',
      assignments: unique_to_you_assignments(teammate, position),
      teammate: teammate,
      requirements: requirements,
      percentage_key: :minimum_percentage_of_assignments
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

  def check_title_department_aspirational_values_check_ins(teammate, position, requirements)
    # Get aspirations for the title's department (if any)
    aspirations = position.title.department ? 
      Aspiration.for_department(position.title.department).ordered : 
      Aspiration.none

    check_aspiration_group(
      key: :title_department_aspirational_values_check_in_requirements,
      label: 'Title/Department Aspirational Values Check-Ins',
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

  def check_assignment_group(key:, label:, assignments:, teammate:, requirements:, percentage_key:)
    minimum_rating = requirements['minimum_rating'] || requirements[:minimum_rating]
    minimum_months = requirements['minimum_months_at_or_above_rating_criteria'] || requirements[:minimum_months_at_or_above_rating_criteria]
    minimum_percentage = requirements[percentage_key.to_s] || requirements[percentage_key]
    return not_configured_check(key) if minimum_rating.blank? || minimum_months.blank? || minimum_percentage.blank?

    total_assignments = assignments.length
    return {
      key: key,
      label: label,
      status: :failed,
      details: {
        minimum_rating: minimum_rating,
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        minimum_percentage: minimum_percentage.to_f,
        total_assignments: total_assignments,
        qualifying_assignments: 0
      }
    } if total_assignments.zero?

    qualifying_assignments = assignments.count do |assignment|
      assignment_meets_check_in_requirement?(teammate, assignment, minimum_rating, minimum_months.to_i)
    end

    percentage = (qualifying_assignments.to_f / total_assignments) * 100.0
    passed = percentage >= minimum_percentage.to_f
    missing_assignments = [((minimum_percentage.to_f / 100.0) * total_assignments).ceil - qualifying_assignments, 0].max

    {
      key: key,
      label: label,
      status: passed ? :passed : :failed,
      details: {
        minimum_rating: minimum_rating,
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        minimum_percentage: minimum_percentage.to_f,
        total_assignments: total_assignments,
        qualifying_assignments: qualifying_assignments,
        qualifying_percentage: percentage,
        next_steps: passed ? nil : "Needs #{missing_assignments} more assignments meeting criteria"
      }
    }
  end

  def check_aspiration_group(key:, label:, aspirations:, teammate:, requirements:)
    minimum_rating = requirements['minimum_rating'] || requirements[:minimum_rating]
    minimum_months = requirements['minimum_months_at_or_above_rating_criteria'] || requirements[:minimum_months_at_or_above_rating_criteria]
    minimum_percentage = requirements['minimum_percentage_of_aspirational_values'] || requirements[:minimum_percentage_of_aspirational_values]
    return not_configured_check(key) if minimum_rating.blank? || minimum_months.blank? || minimum_percentage.blank?

    total_aspirations = aspirations.length
    return {
      key: key,
      label: label,
      status: :failed,
      details: {
        minimum_rating: minimum_rating,
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        minimum_percentage: minimum_percentage.to_f,
        total_aspirations: total_aspirations,
        qualifying_aspirations: 0
      }
    } if total_aspirations.zero?

    qualifying_aspirations = aspirations.count do |aspiration|
      aspiration_meets_check_in_requirement?(teammate, aspiration, minimum_rating, minimum_months.to_i)
    end

    percentage = (qualifying_aspirations.to_f / total_aspirations) * 100.0
    passed = percentage >= minimum_percentage.to_f
    missing_values = [((minimum_percentage.to_f / 100.0) * total_aspirations).ceil - qualifying_aspirations, 0].max

    {
      key: key,
      label: label,
      status: passed ? :passed : :failed,
      details: {
        minimum_rating: minimum_rating,
        minimum_months_at_or_above_rating_criteria: minimum_months.to_i,
        minimum_percentage: minimum_percentage.to_f,
        total_aspirations: total_aspirations,
        qualifying_aspirations: qualifying_aspirations,
        qualifying_percentage: percentage,
        next_steps: passed ? nil : "Needs #{missing_values} more values meeting criteria"
      }
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
