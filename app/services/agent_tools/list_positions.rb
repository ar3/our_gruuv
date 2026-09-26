# frozen_string_literal: true

module AgentTools
  # Non-archived positions visible via PositionPolicy::Scope + show?.
  # Positions carry Assignments (energy + required/suggested); Titles do not.
  class ListPositions < Base
    DEFAULT_LIMIT = ListPagination::DEFAULT_LIMIT
    ASSIGNMENT_LINK_VALUES = %w[required suggested all].freeze
    DEFAULT_ASSIGNMENT_LINK = "required"

    def call(
      context:,
      query: nil,
      title_path: nil,
      title_id: nil,
      assignment_path: nil,
      assignment_id: nil,
      assignment_link: DEFAULT_ASSIGNMENT_LINK,
      limit: DEFAULT_LIMIT,
      offset: 0,
      detail: Detail::DEFAULT,
      **_ignored
    )
      context.authorize!(context.organization, :show?)
      detail_level = Detail.normalize(detail)
      company = company_for(context)
      link_filter = normalize_assignment_link(assignment_link)

      relation = context.policy_scope(Position).unarchived.for_company(company).ordered
      relation = relation.includes(:position_level, title: :department)

      if title_path.present? || title_id.present?
        title = RecordPaths.resolve_title(context, title_path: title_path, title_id: title_id)
        return err("title not found", code: "not_found") if title.nil?
        return err("title not in organization", code: "validation_failed") unless title.company_id == company.id

        relation = relation.where(title_id: title.id)
      end

      if assignment_path.present? || assignment_id.present?
        assignment = RecordPaths.resolve_assignment(
          context,
          assignment_path: assignment_path,
          assignment_id: assignment_id
        )
        return err("assignment not found", code: "not_found") if assignment.nil?
        return err("assignment not in organization", code: "validation_failed") unless assignment.company_id == company.id

        pa_scope = PositionAssignment.where(assignment_id: assignment.id)
        pa_scope = pa_scope.where(assignment_type: link_filter) unless link_filter == "all"
        relation = relation.where(id: pa_scope.select(:position_id))
      end

      if Detail.expensive?(detail_level)
        relation = relation.includes(position_assignments: :assignment)
      end

      positions, = ListPagination.scan_relation(relation)
      needle = query.to_s.strip.downcase
      if needle.present?
        positions = positions.select { |position| position_matches?(position, needle) }
      end

      visible = positions.select { |position|
        Pundit.policy(context.pundit_user, position).show?
      }
      page = ListPagination.slice(visible, limit: limit, offset: offset)

      ok(
        {
          positions: page[:items].map { |p| MaapSerializers.position(context, p, detail: detail_level) },
          detail: detail_level,
          detail_hint: ListPagination::DETAIL_TOKEN_HINT,
          assignment_link: link_filter,
          note:
            "Positions carry Assignments. Titles do not. " \
            "Filter with assignment_path for reverse lookup; assignment_link defaults to required " \
            "(pass suggested or all). Compact summary also on get_assignment."
        }.merge(page[:meta])
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

    def normalize_assignment_link(value)
      link = value.to_s.strip.presence || DEFAULT_ASSIGNMENT_LINK
      return link if ASSIGNMENT_LINK_VALUES.include?(link)

      raise ArgumentError, "assignment_link must be one of: #{ASSIGNMENT_LINK_VALUES.join(', ')}"
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
