# frozen_string_literal: true

# Builds per-ability rows for My Growth > Abilities: union of earned milestones and
# current/target position milestone requirements (direct position abilities + required assignments).
class MyGrowthAbilityMilestoneRows
  # @return [Hash<Integer, Hash>] ability_id => { minimum_milestone_level:, sources: [{ kind:, level:, assignment: }] }
  def self.structured_requirements_by_ability_id(position)
    return {} unless position

    grouped = Hash.new { |h, k| h[k] = { levels: [], sources: [] } }

    position.position_abilities.each do |pa|
      next unless pa.ability_id.present? && pa.milestone_level.present?

      level = pa.milestone_level.to_i
      grouped[pa.ability_id][:levels] << level
      grouped[pa.ability_id][:sources] << { kind: :direct, level: level, assignment: nil }
    end

    position.required_assignments.each do |position_assignment|
      assignment = position_assignment.assignment
      assignment&.assignment_abilities&.each do |aa|
        next unless aa.ability_id.present? && aa.milestone_level.present?

        level = aa.milestone_level.to_i
        grouped[aa.ability_id][:levels] << level
        grouped[aa.ability_id][:sources] << { kind: :assignment, level: level, assignment: assignment }
      end
    end

    return {} if grouped.empty?

    abilities = Ability.where(id: grouped.keys).index_by(&:id)
    grouped.each_with_object({}) do |(ability_id, data), out|
      next unless abilities[ability_id]

      out[ability_id] = {
        minimum_milestone_level: data[:levels].max,
        sources: normalize_sources(data[:sources])
      }
    end
  end

  # @return [Array<Hash>] rows sorted by ability name; each row has :ability, :earned_levels, :current, :target
  #   :current / :target are nil or { minimum_milestone_level:, sources: }
  def self.build(teammate:, current_position:, target_position:)
    earned_addends = EligibilityMileageAddends.earned_for(teammate)[:addends]
    earned_by_ability_id = earned_addends.index_by { |a| a[:ability_id] }

    current_map = structured_requirements_by_ability_id(current_position)
    target_map = structured_requirements_by_ability_id(target_position)

    ability_ids = (earned_by_ability_id.keys + current_map.keys + target_map.keys).uniq
    return [] if ability_ids.empty?

    abilities = Ability.where(id: ability_ids).index_by(&:id)

    ability_ids.filter_map do |ability_id|
      ability = abilities[ability_id]
      next unless ability

      earned_levels = earned_by_ability_id[ability_id]&.fetch(:levels, []) || []

      {
        ability: ability,
        earned_levels: earned_levels,
        current: current_map[ability_id],
        target: target_map[ability_id]
      }
    end.sort_by { |r| r[:ability].name.to_s.downcase }
  end

  def self.normalize_sources(sources)
    seen = {}
    out = []
    sources.each do |s|
      key = case s[:kind]
            when :direct
              [:direct, s[:level].to_i]
            when :assignment
              [:assignment, s[:assignment]&.id, s[:level].to_i]
            end
      next if seen[key]

      seen[key] = true
      out << s
    end
    out
  end
  private_class_method :normalize_sources
end
