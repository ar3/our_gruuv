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
end
