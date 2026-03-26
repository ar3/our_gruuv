# Builds earned/required milestone mileage addends for eligibility section (7).
# Used by EligibilityRequirementsController and My Growth (Abilities tab).
class EligibilityMileageAddends
  def self.earned_for(teammate)
    return { addends: [], total: 0 } unless teammate

    mileage_service = MilestoneMileageService.new
    milestones = teammate.teammate_milestones.includes(:ability).order(:milestone_level, :attained_at)
    by_ability = milestones.group_by { |m| [m.ability_id, m.ability.name] }
    addends = by_ability.map do |(_ability_id, ability_name), group|
      levels = group.map(&:milestone_level).sort.uniq
      points = group.sum { |m| mileage_service.milestone_points(m.milestone_level) }
      { ability_name: ability_name, levels: levels, points: points }
    end.sort_by { |a| a[:ability_name] }
    { addends: addends, total: mileage_service.total_mileage_for(teammate) }
  end

  def self.required_for(position)
    return { addends: [], total: 0 } unless position

    mileage_service = MilestoneMileageService.new
    max_level_by_ability = {} # ability_id => { name:, level: }

    position.position_abilities.includes(:ability).each do |pa|
      id = pa.ability_id
      if max_level_by_ability[id].nil? || pa.milestone_level > max_level_by_ability[id][:level]
        max_level_by_ability[id] = { name: pa.ability.name, level: pa.milestone_level }
      end
    end
    position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.includes(:ability).each do |aa|
        id = aa.ability_id
        if max_level_by_ability[id].nil? || aa.milestone_level > max_level_by_ability[id][:level]
          max_level_by_ability[id] = { name: aa.ability.name, level: aa.milestone_level }
        end
      end
    end

    addends = max_level_by_ability.values.map do |info|
      level = info[:level]
      levels = (1..level).to_a
      { ability_name: info[:name], levels: levels, points: mileage_service.points_through_milestone(level) }
    end.sort_by { |a| a[:ability_name] }
    total = addends.sum { |a| a[:points] }
    { addends: addends, total: total }
  end
end
