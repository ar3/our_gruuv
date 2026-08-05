# frozen_string_literal: true

module AgentTools
  # Shared assignment / ability serialization for list tools and search_organization.
  module MaapSerializers
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
  end
end
