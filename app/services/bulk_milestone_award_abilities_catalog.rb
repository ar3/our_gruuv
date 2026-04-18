# frozen_string_literal: true

# Collects abilities tied to a teammate for bulk milestone adjustment: assignment tenures,
# current position (required, suggested, direct position abilities), and target/next goal
# position (same). Used for the bulk award wizard and server-side validation.
class BulkMilestoneAwardAbilitiesCatalog
  Source = Struct.new(:kind, :milestone_level, :assignment, :position, :position_context, keyword_init: true)

  def self.call(teammate:, organization:)
    new(teammate:, organization:).call
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
      highest_awarded = @teammate.teammate_milestones.where(ability_id: aid).maximum(:milestone_level).to_i

      {
        ability: ability,
        ability_id: aid,
        display_name: ability.display_name,
        source_summary_lines: source_summary_lines(sources),
        requirement_rows: requirement_display_rows(sources),
        sources: sources,
        requirements_by_level: requirements_by_level(sources),
        highest_awarded: highest_awarded
      }
    end.sort_by { |r| r[:display_name].to_s.downcase }
  end

  def self.ability_ids_for(teammate:, organization:)
    new(teammate:, organization:).send(:collect_ability_ids)
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

    position.position_assignments.includes(assignment: :assignment_abilities).each do |pa|
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

    position.position_assignments.includes(assignment: :assignment_abilities).each do |pa|
      assignment = pa.assignment
      next unless assignment

      aa = assignment.assignment_abilities.find_by(ability: ability)
      next unless aa&.milestone_level.present?

      kind = pa.assignment_type == 'suggested' ? :suggested_assignment : :required_assignment
      out << Source.new(
        kind: kind,
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

  # Rows for "why this ability" accordion: one row per assignment (or per position for direct
  # position abilities), M{n} = highest milestone requirement among merged sources, plus tooltip/links.
  def requirement_display_rows(sources)
    buckets = {}
    sources.each do |s|
      key, label = requirement_row_key_and_label(s)
      next unless key && label

      slot = buckets[key] ||= { label: label, milestone_level: 0, sources: [] }
      slot[:sources] << s
      slot[:milestone_level] = [slot[:milestone_level], s.milestone_level.to_i].max
    end

    buckets.map do |key, slot|
      kind = key[0]
      tooltip = case kind
                  when :assignment
                    assignment_requirement_tooltip(slot[:sources])
                  when :position_direct
                    position_direct_requirement_tooltip(slot[:sources])
                  else
                    ''
                  end

      row = {
        label: slot[:label],
        milestone_level: slot[:milestone_level],
        tooltip: tooltip
      }
      if kind == :assignment
        row[:assignment] = slot[:sources].find { |src| src.assignment.present? }&.assignment
      elsif kind == :position_direct
        row[:teammate_position_link] = true
      end
      row
    end.sort_by { |r| [r[:label].to_s.downcase, r[:milestone_level]] }
  end

  def requirement_row_key_and_label(source)
    case source.kind
    when :assignment_tenure, :required_assignment, :suggested_assignment
      return [nil, nil] unless source.assignment

      [[:assignment, source.assignment.id], source.assignment.title]
    when :position_direct
      return [nil, nil] unless source.position

      [[:position_direct, source.position.id], source.position.display_name]
    else
      [nil, nil]
    end
  end

  def assignment_requirement_tooltip(sources)
    parts = []
    casual = @teammate.person.casual_name.presence || 'This teammate'

    cur_req = sources.find { |s| s.kind == :required_assignment && s.position_context == :current }
    cur_sug = sources.find { |s| s.kind == :suggested_assignment && s.position_context == :current }
    if cur_req
      parts << "Current position (#{cur_req.position.display_name}): this assignment is required on the blueprint."
    elsif cur_sug
      parts << "Current position (#{cur_sug.position.display_name}): this assignment is suggested on the blueprint."
    else
      parts << 'This assignment is not on their current position blueprint as required or suggested.'
    end

    if @teammate.next_goal_position.present?
      tar_req = sources.find { |s| s.kind == :required_assignment && s.position_context == :target }
      tar_sug = sources.find { |s| s.kind == :suggested_assignment && s.position_context == :target }
      if tar_req
        parts << "Target position (#{tar_req.position.display_name}): this assignment is required on the blueprint."
      elsif tar_sug
        parts << "Target position (#{tar_sug.position.display_name}): this assignment is suggested on the blueprint."
      else
        parts << 'This assignment is not on their target position blueprint as required or suggested.'
      end
    else
      parts << 'They have no target position set, so no target blueprint applies to this assignment.'
    end

    if sources.any? { |s| s.kind == :assignment_tenure }
      parts << "#{casual} is actively assigned to this assignment."
    end

    parts.join(' ')
  end

  def position_direct_requirement_tooltip(sources)
    s = sources.first
    return '' unless s&.position

    pos = s.position.display_name
    case s.position_context
    when :current
      "Current position (#{pos}): this ability is required directly on the position (not only via an assignment)."
    when :target
      "Target position (#{pos}): this ability is required directly on the position (not only via an assignment)."
    else
      "This ability is required directly on #{pos}."
    end
  end

  def source_summary_lines(sources)
    sources.map { |s| source_label(s) }.uniq.sort
  end

  def source_label(source)
    case source.kind
    when :assignment_tenure
      "Assignment tenure: #{source.assignment.title}"
    when :required_assignment
      "Required (#{source.position.display_name}): #{source.assignment.title}"
    when :suggested_assignment
      "Suggested (#{source.position.display_name}): #{source.assignment.title}"
    when :position_direct
      "Position (#{source.position.display_name})"
    else
      source.kind.to_s.humanize
    end
  end

  def requirements_by_level(sources)
    by = Hash.new { |h, k| h[k] = [] }
    sources.each do |s|
      level = s.milestone_level.to_i
      next if level < 1 || level > 5

      short = case s.kind
              when :position_direct
                s.position&.display_name
              else
                s.assignment&.title
              end
      next if short.blank?

      by[level] << "#{short} (M#{level})"
    end
    by.transform_values(&:uniq)
  end
end
