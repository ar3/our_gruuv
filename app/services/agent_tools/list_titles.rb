# frozen_string_literal: true

module AgentTools
  # Non-archived titles. Titles are not Assignment-carriers; use child positions for that.
  # path_clarity (definition B): clear if end_cap OR has outbound TitlePath.
  class ListTitles < Base
    DEFAULT_LIMIT = 25

    def call(
      context:,
      query: nil,
      department_path: nil,
      department_id: nil,
      limit: DEFAULT_LIMIT,
      detail: Detail::DEFAULT,
      **_ignored
    )
      context.authorize!(context.organization, :show?)
      detail_level = Detail.normalize(detail)
      company = company_for(context)

      relation = context.policy_scope(Title).unarchived.for_company(company).ordered
      relation = relation.includes(:department, :position_major_level, :inbound_title_paths, :outbound_title_paths)

      if department_path.present? || department_id.present?
        department = RecordPaths.resolve_department(
          context,
          department_path: department_path,
          department_id: department_id
        )
        return err("department not found", code: "not_found") if department.nil?
        return err("department not in organization", code: "validation_failed") unless department.company_id == company.id

        dept_ids = department.self_and_descendants.map(&:id)
        relation = relation.where(department_id: dept_ids)
      end

      if Detail.expensive?(detail_level)
        relation = relation.includes(positions: :position_level, inbound_title_paths: :from_title, outbound_title_paths: :to_title)
      end

      titles = relation.limit(200).to_a
      needle = query.to_s.strip.downcase
      if needle.present?
        titles = titles.select { |title| title.external_title.to_s.downcase.include?(needle) }
      end

      visible = titles.select { |title|
        Pundit.policy(context.pundit_user, title).show?
      }.first(limit.to_i.clamp(1, 50))

      ok(
        titles: visible.map { |t| MaapSerializers.title(context, t, detail: detail_level) },
        count: visible.size,
        detail: detail_level,
        note: MaapSerializers::TITLE_NOT_ASSIGNMENT_CARRIER,
        path_clarity_definition: "clear if end_cap or has outbound TitlePath; inbound-only is missing"
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
  end
end
