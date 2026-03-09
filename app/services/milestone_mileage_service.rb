class MilestoneMileageService
  MILESTONE_POINTS = {
    1 => 1,
    2 => 2,
    3 => 3,
    4 => 6,
    5 => 8
  }.freeze

  def total_mileage_for(teammate)
    return 0 unless teammate

    teammate.teammate_milestones.sum do |milestone|
      milestone_points(milestone.milestone_level)
    end
  end

  def mileage_for_ability(teammate, ability)
    return 0 unless teammate && ability

    teammate.teammate_milestones.where(ability: ability).sum do |milestone|
      milestone_points(milestone.milestone_level)
    end
  end

  def milestone_points(milestone_level)
    MILESTONE_POINTS[milestone_level.to_i] || 0
  end

  # Points for requiring a given milestone level = sum of points for milestones 1 through level
  # (requiring Milestone 3 implies Milestones 1 and 2, so 1 + 2 + 3 = 6 points).
  def points_through_milestone(level)
    return 0 if level.to_i < 1
    (1..level.to_i).sum { |l| milestone_points(l) }
  end

  # Sum of milestone points for position abilities + required assignment abilities (minimum "base" for this position).
  # Per ability we take the highest required level, then add cumulative points for that level.
  def minimum_required_for_position(position)
    return 0 unless position

    max_level_by_ability = {}
    position.position_abilities.each do |pa|
      key = pa.ability_id
      max_level_by_ability[key] = [max_level_by_ability[key].to_i, pa.milestone_level].max
    end
    position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.each do |aa|
        key = aa.ability_id
        max_level_by_ability[key] = [max_level_by_ability[key].to_i, aa.milestone_level].max
      end
    end
    max_level_by_ability.values.sum { |level| points_through_milestone(level) }
  end
end
