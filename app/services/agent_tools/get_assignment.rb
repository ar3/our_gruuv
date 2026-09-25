# frozen_string_literal: true

module AgentTools
  # Single assignment by path (preferred) or id.
  # Includes AssignmentAbility rows as level + ability path/name (no milestone prose).
  class GetAssignment < Base
    def call(context:, path: nil, assignment_path: nil, assignment_id: nil, **_ignored)
      context.authorize!(context.organization, :show?)
      company = context.organization.root_company || context.organization

      if path.blank? && assignment_path.blank? && assignment_id.blank?
        return err("path is required", code: "validation_failed")
      end

      assignment = RecordPaths.resolve_assignment(
        context,
        path: path,
        assignment_path: assignment_path,
        assignment_id: assignment_id
      )
      return err("assignment not found", code: "not_found") if assignment.nil?
      return err("assignment not in organization", code: "validation_failed") unless assignment.company_id == company.id
      return err("assignment is archived", code: "not_found") if assignment.archived?

      context.authorize!(assignment, :show?)

      assignment = Assignment.includes(:assignment_outcomes, assignment_abilities: :ability).find(assignment.id)

      ok(
        assignment: MaapSerializers.assignment(context, assignment, detail: Detail::DEFAULT).merge(
          abilities: MaapSerializers.assignment_ability_links(context, assignment)
        ),
        note: "Ability rows are milestone_level + path/name only. Milestone prose: use get_ability."
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end
  end
end
