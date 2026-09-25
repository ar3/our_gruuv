# frozen_string_literal: true

module AgentTools
  # Single title by path (preferred) or id. Includes child positions and path edges.
  # Titles do not carry Assignments — use positions for that.
  class GetTitle < Base
    def call(context:, path: nil, title_path: nil, title_id: nil, **_ignored)
      context.authorize!(context.organization, :show?)
      company = context.organization.root_company || context.organization

      if path.blank? && title_path.blank? && title_id.blank?
        return err("path is required", code: "validation_failed")
      end

      title = RecordPaths.resolve_title(
        context,
        path: path,
        title_path: title_path,
        title_id: title_id
      )
      return err("title not found", code: "not_found") if title.nil?
      return err("title not in organization", code: "validation_failed") unless title.company_id == company.id
      return err("title is archived", code: "not_found") if title.archived?

      context.authorize!(title, :show?)

      title = Title.includes(
        :department,
        :position_major_level,
        { positions: :position_level },
        { inbound_title_paths: :from_title },
        { outbound_title_paths: :to_title }
      ).find(title.id)

      ok(
        title: MaapSerializers.title(context, title, detail: Detail::DEFAULT),
        note: MaapSerializers::TITLE_NOT_ASSIGNMENT_CARRIER,
        path_clarity_definition: "clear if end_cap or has outbound TitlePath; inbound-only is missing"
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end
  end
end
