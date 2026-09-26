# frozen_string_literal: true

module AgentTools
  # Single ability by path (preferred) or id. Full body including milestone descriptions.
  # Reverse: assignments that require it + positions that require it (rollup).
  class GetAbility < Base
    def call(context:, path: nil, ability_path: nil, ability_id: nil, **_ignored)
      context.authorize!(context.organization, :show?)
      company = context.organization.root_company || context.organization

      if path.blank? && ability_path.blank? && ability_id.blank?
        return err("path is required", code: "validation_failed")
      end

      ability = RecordPaths.resolve_ability(
        context,
        path: path,
        ability_path: ability_path,
        ability_id: ability_id
      )
      return err("ability not found", code: "not_found") if ability.nil?
      return err("ability not in organization", code: "validation_failed") unless ability.company_id == company.id
      return err("ability is archived", code: "not_found") if ability.archived?

      context.authorize!(ability, :show?)

      ability = Ability.includes(assignment_abilities: :assignment).find(ability.id)

      ok(
        ability: MaapSerializers.ability(context, ability, detail: Detail::DEFAULT).merge(
          assignments: MaapSerializers.ability_assignments(context, ability),
          positions: MaapSerializers.ability_requiring_positions(context, ability)
        ),
        note:
          "Full ability body including milestone_1–5_description. " \
          "assignments / positions are compact reverse lookups " \
          "(positions = direct PositionAbility ∪ required Assignments). " \
          "For paginated assignment browse: list_assignments(ability_path=...)."
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end
  end
end
