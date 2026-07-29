# frozen_string_literal: true

module AgentTools
  # Permission-filtered sitemap catalog (same source as Organizations::SitemapController).
  class ListSitemap < Base
    def call(context:, **_ignored)
      context.authorize!(context.organization, :show?)

      sitemap_context = OrganizationSitemap::Context.new(
        organization: context.organization,
        teammate: context.company_teammate,
        impersonating_teammate: context.pundit_user.try(:impersonating_teammate)
      )
      builder = OrganizationSitemap::Builder.new(context: sitemap_context)
      sections = builder.sections.map do |section|
        {
          section: section[:label],
          pages: section[:entries].map { |entry| serialize_entry(entry) }
        }
      end

      ok(
        sections: sections,
        page_count: builder.entries.size
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def serialize_entry(entry)
      {
        label: entry.label,
        path: entry.path,
        section: entry.section_label,
        goal: entry.goal,
        also_known_as: Array(entry.synonyms)
      }
    end
  end
end
