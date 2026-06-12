# frozen_string_literal: true

class Organizations::SitemapController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized

  def show
    authorize company, :show?

    @sitemap_sections = sitemap_builder.sections
    @sitemap_entry_count = sitemap_builder.entries.size
  end

  private

  def sitemap_builder
    @sitemap_builder ||= OrganizationSitemap::Builder.new(context: sitemap_context)
  end

  def sitemap_context
    OrganizationSitemap::Context.new(
      organization: @organization,
      teammate: current_company_teammate,
      view: view_context,
      impersonating_teammate: impersonating_teammate
    )
  end
end
