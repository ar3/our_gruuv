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

  # Sum of milestone points for position abilities + required assignment abilities (minimum "base" for this position).
  def minimum_required_for_position(position)
    return 0 unless position

    total_points = 0
    position.position_abilities.each do |pa|
      total_points += milestone_points(pa.milestone_level)
    end
    position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.each do |aa|
        total_points += milestone_points(aa.milestone_level)
      end
    end
    total_points
  end
end
