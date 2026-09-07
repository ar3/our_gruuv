# frozen_string_literal: true

# Abilities for one-time milestone calibration: same sources as bulk award (C), but
# excludes abilities that appear only via suggested position assignments (C-suggested).
class AbilityMilestoneCalibrationAbilitiesCatalog
  Source = Struct.new(:kind, :milestone_level, :assignment, :position, :position_context, keyword_init: true)

  def self.call(teammate:, organization:)
    new(teammate:, organization:).call
  end

  def self.ability_ids_for(teammate:, organization:)
    new(teammate:, organization:).send(:collect_ability_ids)
  end

  # Numerator: abilities in set at M0 (will show in ritual). Denominator: full set size.
  def self.entry_counts(teammate:, organization:)
    rows = call(teammate:, organization:)
    full_set = rows.size
    will_show = rows.count { |r| r[:highest_awarded].to_i < 1 }
    { will_show: will_show, full_set: full_set, rows: rows }
  end

  def initialize(teammate:, organization:)
    @teammate = teammate
    @organization = organization
  end

  def call
    ability_ids = collect_ability_ids
    return [] if ability_ids.empty?

    company = @organization.root_company || @organization
    abilities = Ability.unarchived.where(id: ability_ids.to_a, company: company)
      .includes(:assignment_abilities)
      .order(:name)
      .index_by(&:id)

    ability_ids.filter_map do |aid|
      ability = abilities[aid]
      next unless ability

      sources = sources_for_ability(ability)
      next if sources.empty?

      highest_awarded = @teammate.teammate_milestones.where(ability_id: aid).maximum(:milestone_level).to_i

      {
        ability: ability,
        ability_id: aid,
        display_name: ability.display_name,
        sources: sources,
        highest_awarded: highest_awarded
      }
    end.sort_by { |r| r[:display_name].to_s.downcase }
  end

  private

  def collect_ability_ids
    ids = Set.new
    company_scope = @organization.self_and_descendants

    AssignmentTenure
      .where(company_teammate: @teammate)
      .joins(:assignment)
      .where(assignments: { company: company_scope })
      .includes(assignment: :assignment_abilities)
      .find_each do |tenure|
        tenure.assignment.assignment_abilities.each { |aa| ids.add(aa.ability_id) if aa.ability_id.present? }
      end

    active_tenure = @teammate.active_employment_tenure
    add_position_ability_sources(active_tenure&.position, ids)

    target = @teammate.next_goal_position
    add_position_ability_sources(target, ids) if target.present?

    ids
  end

  def add_position_ability_sources(position, ids)
    return unless position

    position = Position.includes(
      { position_abilities: :ability },
      position_assignments: { assignment: { assignment_abilities: :ability } }
    ).find(position.id)

    position.position_abilities.each { |pa| ids.add(pa.ability_id) if pa.ability_id.present? }

    position.position_assignments.required.includes(assignment: :assignment_abilities).each do |pa|
      pa.assignment&.assignment_abilities&.each do |aa|
        ids.add(aa.ability_id) if aa.ability_id.present?
      end
    end
  end

  def sources_for_ability(ability)
    list = []
    company_scope = @organization.self_and_descendants

    AssignmentTenure
      .where(company_teammate: @teammate)
      .joins(:assignment)
      .where(assignments: { company: company_scope })
      .includes(assignment: :assignment_abilities)
      .find_each do |tenure|
        aa = tenure.assignment.assignment_abilities.find_by(ability: ability)
        next unless aa&.milestone_level.present?

        list << Source.new(
          kind: :assignment_tenure,
          milestone_level: aa.milestone_level.to_i,
          assignment: tenure.assignment,
          position: nil,
          position_context: nil
        )
      end

    active_tenure = @teammate.active_employment_tenure
    if active_tenure&.position
      list.concat(sources_from_position(active_tenure.position, ability, :current))
    end

    if @teammate.next_goal_position.present?
      list.concat(sources_from_position(@teammate.next_goal_position, ability, :target))
    end

    dedupe_sources(list)
  end

  def sources_from_position(position, ability, position_context)
    position = Position.includes(
      { position_abilities: :ability },
      position_assignments: { assignment: { assignment_abilities: :ability } }
    ).find(position.id)

    out = []

    position.position_abilities.where(ability: ability).each do |pa|
      next unless pa.milestone_level.present?

      out << Source.new(
        kind: :position_direct,
        milestone_level: pa.milestone_level.to_i,
        assignment: nil,
        position: position,
        position_context: position_context
      )
    end

    position.position_assignments.required.includes(assignment: :assignment_abilities).each do |pa|
      assignment = pa.assignment
      next unless assignment

      aa = assignment.assignment_abilities.find_by(ability: ability)
      next unless aa&.milestone_level.present?

      out << Source.new(
        kind: :required_assignment,
        milestone_level: aa.milestone_level.to_i,
        assignment: assignment,
        position: position,
        position_context: position_context
      )
    end

    out
  end

  def dedupe_sources(list)
    seen = Set.new
    list.select do |s|
      key = [s.kind, s.milestone_level, s.assignment&.id, s.position&.id, s.position_context]
      next false if seen.include?(key)

      seen.add(key)
      true
    end
  end
end
