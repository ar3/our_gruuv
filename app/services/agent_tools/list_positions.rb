# frozen_string_literal: true

module AgentTools
  # Non-archived positions visible via PositionPolicy::Scope + show?.
  # Positions carry Assignments (energy + required/suggested); Titles do not.
  class ListPositions < Base
    DEFAULT_LIMIT = 25

    def call(
      context:,
      query: nil,
      title_path: nil,
      title_id: nil,
      limit: DEFAULT_LIMIT,
      detail: Detail::DEFAULT,
      **_ignored
    )
      context.authorize!(context.organization, :show?)
      detail_level = Detail.normalize(detail)
      company = company_for(context)

      relation = context.policy_scope(Position).unarchived.for_company(company).ordered
      relation = relation.includes(:position_level, title: :department)

      if title_path.present? || title_id.present?
        title = RecordPaths.resolve_title(context, title_path: title_path, title_id: title_id)
        return err("title not found", code: "not_found") if title.nil?
        return err("title not in organization", code: "validation_failed") unless title.company_id == company.id

        relation = relation.where(title_id: title.id)
      end

      if Detail.expensive?(detail_level)
        relation = relation.includes(position_assignments: :assignment)
      end

      positions = relation.limit(200).to_a
      needle = query.to_s.strip.downcase
      if needle.present?
        positions = positions.select { |position| position_matches?(position, needle) }
      end

      visible = positions.select { |position|
        Pundit.policy(context.pundit_user, position).show?
      }.first(limit.to_i.clamp(1, 50))

      ok(
        positions: visible.map { |p| MaapSerializers.position(context, p, detail: detail_level) },
        count: visible.size,
        detail: detail_level,
        note: "Positions carry Assignments. Titles do not."
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end

    private

    def company_for(context)
      context.organization.root_company || context.organization
    end

    def position_matches?(position, needle)
      [
        position.display_name,
        position.title&.external_title,
        position.position_level&.level,
        position.position_summary
      ].compact.any? { |text| text.to_s.downcase.include?(needle) }
    end
  end
end
