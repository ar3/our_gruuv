# frozen_string_literal: true

require "ostruct"

module OrganizationSitemap
  class Context
    include Rails.application.routes.url_helpers
    include CompanyLabelHelper

    attr_reader :organization, :teammate, :view, :impersonating_teammate

    def initialize(organization:, teammate:, view: nil, impersonating_teammate: nil)
      @organization = organization
      @teammate = teammate
      @view = view
      @impersonating_teammate = impersonating_teammate
    end

    def company
      organization&.root_company || organization
    end

    def current_organization
      organization
    end

    def current_company_teammate
      teammate
    end

    def casual_name
      teammate&.person&.casual_name.presence || "Me"
    end

    def org_display_name
      organization&.name.presence || "Organization"
    end

    def policy(record)
      if view.present?
        view.policy(record)
      else
        pundit_user = OpenStruct.new(user: teammate, impersonating_teammate: impersonating_teammate)
        Pundit.policy!(pundit_user, record)
      end
    end

    def resolve_label(label)
      label.respond_to?(:call) ? label.call(self) : label.to_s
    end

    def resolve_path(path_proc)
      return nil if path_proc.blank?

      path = path_proc.call(self)
      path = path.to_s
      path.presence unless path == "#"
    rescue StandardError => e
      Rails.logger.error("Organization sitemap path resolution failed: #{e.message}")
      nil
    end

    def allowed?(policy_proc)
      return false if policy_proc.blank?

      policy_proc.call(self)
    rescue StandardError => e
      Rails.logger.error("Organization sitemap policy check failed: #{e.message}")
      false
    end
  end
end
