# frozen_string_literal: true

module AgentTools
  # Shared assignment / ability / position / title serialization for AgentTools.
  module MaapSerializers
    TITLE_NOT_ASSIGNMENT_CARRIER =
      "Titles do not carry Assignments. Positions do — use list_positions / get_position " \
      "(or get_title child positions)."

    module_function

    def assignment(context, assignment, detail: Detail::DEFAULT)
      base = {
        title: assignment.title,
        path: RecordPaths.assignment_path(context, assignment)
      }
      return base unless Detail.expensive?(detail)

      base.merge(
        tagline: assignment.tagline,
        required_activities: assignment.required_activities,
        handbook: assignment.handbook,
        outcomes: assignment.assignment_outcomes.ordered.filter_map { |o| o.description.presence }
      )
    end

    def ability(context, ability, detail: Detail::DEFAULT)
      base = {
        name: ability.name,
        path: RecordPaths.ability_path(context, ability)
      }
      return base unless Detail.expensive?(detail)

      base.merge(
        description: ability.description,
        milestone_1_description: ability.milestone_1_description.presence,
        milestone_2_description: ability.milestone_2_description.presence,
        milestone_3_description: ability.milestone_3_description.presence,
        milestone_4_description: ability.milestone_4_description.presence,
        milestone_5_description: ability.milestone_5_description.presence
      )
    end

    def position_assignment_link(context, position_assignment)
      assignment = position_assignment.assignment
      {
        title: assignment&.title,
        path: assignment ? RecordPaths.assignment_path(context, assignment) : nil,
        assignment_type: position_assignment.assignment_type,
        min_estimated_energy: position_assignment.min_estimated_energy,
        max_estimated_energy: position_assignment.max_estimated_energy,
        anticipated_energy_percentage: position_assignment.anticipated_energy_percentage,
        energy_range_display: position_assignment.energy_range_display
      }
    end

    def position(context, position, detail: Detail::DEFAULT, include_assignments: nil)
      include_assignments = Detail.expensive?(detail) if include_assignments.nil?
      title = position.title
      base = {
        display_name: position.display_name,
        path: RecordPaths.position_path(context, position),
        level: position.position_level&.level,
        title: {
          title: title&.external_title,
          path: title ? RecordPaths.title_path(context, title) : nil,
          carries_assignments: false
        }
      }
      return base unless include_assignments

      pas = position.position_assignments.includes(:assignment).ordered_by_max_energy_then_title
      base.merge(
        assignments: pas.map { |pa| position_assignment_link(context, pa) }
      )
    end

    def title_summary(context, title)
      {
        title: title.external_title,
        path: RecordPaths.title_path(context, title),
        carries_assignments: false,
        note: TITLE_NOT_ASSIGNMENT_CARRIER
      }
    end

    def title(context, title, detail: Detail::DEFAULT)
      outbound = title.outbound_title_paths.to_a
      path_clarity, path_clarity_reason = title_path_clarity(title, outbound)

      base = title_summary(context, title).merge(
        end_cap: title.end_cap?,
        path_clarity: path_clarity,
        path_clarity_reason: path_clarity_reason,
        major_level: title.position_major_level&.major_level,
        department: department_ref(context, title.department)
      )
      return base unless Detail.expensive?(detail)

      positions = title.positions.unarchived.includes(:position_level).sort_by { |p|
        level_tuple(p)
      }
      inbound = title.inbound_title_paths.includes(:from_title).to_a
      outbound_loaded = title.outbound_title_paths.includes(:to_title).to_a

      base.merge(
        positions: positions.map { |p|
          {
            display_name: p.display_name,
            path: RecordPaths.position_path(context, p),
            level: p.position_level&.level
          }
        },
        inbound_paths: inbound.map { |path| title_path_edge(context, path, direction: :inbound) },
        outbound_paths: outbound_loaded.map { |path| title_path_edge(context, path, direction: :outbound) }
      )
    end

    def title_path_clarity(title, outbound = nil)
      outbound ||= title.outbound_title_paths
      if title.end_cap?
        [true, "end_cap"]
      elsif outbound.any?
        [true, "has_outbound"]
      else
        [false, "missing"]
      end
    end

    def title_path_edge(context, path, direction:)
      neighbor = direction == :inbound ? path.from_title : path.to_title
      {
        path_type: path.path_type,
        path_type_label: path.path_type_label,
        title: neighbor&.external_title,
        path: neighbor ? RecordPaths.title_path(context, neighbor) : nil
      }
    end

    def department_ref(context, department)
      return nil if department.nil?

      {
        name: department.name,
        path: RecordPaths.department_path(context, department)
      }
    end

    def level_tuple(position)
      level_str = position.position_level&.level
      major, minor = level_str.to_s.split(".", 2).map(&:to_i)
      [major.to_i, minor.to_i]
    end
  end
end
