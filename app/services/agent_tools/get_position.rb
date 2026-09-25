# frozen_string_literal: true

module AgentTools
  # Single position by path (preferred) or id. Always includes Assignment links with energy.
  class GetPosition < Base
    def call(context:, path: nil, position_path: nil, position_id: nil, **_ignored)
      context.authorize!(context.organization, :show?)
      company = context.organization.root_company || context.organization

      if path.blank? && position_path.blank? && position_id.blank?
        return err("path is required", code: "validation_failed")
      end

      position = RecordPaths.resolve_position(
        context,
        path: path,
        position_path: position_path,
        position_id: position_id
      )
      return err("position not found", code: "not_found") if position.nil?
      return err("position not in organization", code: "validation_failed") unless position.company.id == company.id
      return err("position is archived", code: "not_found") if position.archived?

      context.authorize!(position, :show?)

      position = Position.includes(
        :position_level,
        :position_abilities,
        { title: :department },
        { position_assignments: { assignment: { assignment_abilities: :ability } } }
      ).find(position.id)

      ok(
        position: MaapSerializers.position(
          context,
          position,
          detail: Detail::DEFAULT,
          include_assignments: true,
          include_ability_requirements: true
        ),
        note:
          "Positions carry Assignments (required/suggested + energy). Titles do not. " \
          "required_abilities is the position skill bar (direct + required Assignments). " \
          "Milestone prose: use get_ability."
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end
  end
end
