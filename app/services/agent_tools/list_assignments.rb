# frozen_string_literal: true

module AgentTools
  # Non-archived assignments visible via AssignmentPolicy::Scope + show?.
  class ListAssignments < Base
    DEFAULT_LIMIT = ListPagination::DEFAULT_LIMIT

    def call(
      context:,
      query: nil,
      ability_path: nil,
      ability_id: nil,
      limit: DEFAULT_LIMIT,
      offset: 0,
      detail: Detail::DEFAULT,
      **_ignored
    )
      context.authorize!(context.organization, :show?)
      detail_level = Detail.normalize(detail)

      company = context.organization.root_company || context.organization
      relation = context.policy_scope(Assignment).unarchived.where(company: company).ordered
      relation = relation.includes(:assignment_outcomes) if Detail.expensive?(detail_level)

      ability = nil
      if ability_path.present? || ability_id.present?
        ability = RecordPaths.resolve_ability(
          context,
          ability_path: ability_path,
          ability_id: ability_id
        )
        return err("ability not found", code: "not_found") if ability.nil?
        return err("ability not in organization", code: "validation_failed") unless ability.company_id == company.id

        relation = relation
          .joins(:assignment_abilities)
          .where(assignment_abilities: { ability_id: ability.id })
          .distinct
        relation = relation.includes(:assignment_abilities)
      end

      assignments, = ListPagination.scan_relation(relation)
      needle = query.to_s.strip.downcase
      if needle.present?
        assignments = assignments.select { |assignment| assignment_matches?(assignment, needle) }
      end

      visible = assignments.select { |assignment|
        Pundit.policy(context.pundit_user, assignment).show?
      }
      page = ListPagination.slice(visible, limit: limit, offset: offset)

      rows = page[:items].map { |a|
        row = MaapSerializers.assignment(context, a, detail: detail_level)
        next row unless ability

        aa = a.assignment_abilities.find { |link| link.ability_id == ability.id }
        row.merge(ability_milestone_level: aa&.milestone_level&.to_i)
      }

      ok(
        {
          assignments: rows,
          detail: detail_level,
          detail_hint: ListPagination::DETAIL_TOKEN_HINT,
          note:
            ability ?
              "Filtered to assignments requiring the given ability (ability_milestone_level per row). " \
              "Compact reverse summary also on get_ability." :
              nil
        }.compact.merge(page[:meta])
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end

    private

    def assignment_matches?(assignment, needle)
      [
        assignment.title,
        assignment.tagline,
        assignment.required_activities,
        assignment.handbook
      ].compact.any? { |text| text.to_s.downcase.include?(needle) }
    end
  end
end
