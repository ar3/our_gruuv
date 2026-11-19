# frozen_string_literal: true

module Insights
  # Collapses resource-scoped page visit URLs into route patterns so insights can
  # group "the same page" across teammates / assignments / etc.
  #
  # Example:
  #   /organizations/1-acme/company_teammates/42/check_ins
  #     => /organizations/:organization_id/company_teammates/:company_teammate_id/check_ins
  class PageVisitPathNormalizer
    ID_LIKE_SEGMENT = /\A\d+(?:-[A-Za-z0-9\-]+)?\z/
    PLACEHOLDER_SEGMENT = /\A:[a-z_]+\z/

    def self.call(url)
      new(url).pattern
    end

    def self.label_for(pattern)
      pattern.to_s.split("/").reject(&:blank?).filter_map do |segment|
        next if PLACEHOLDER_SEGMENT.match?(segment)
        next if segment == "organizations"

        segment.tr("_", " ").humanize
      end.join(" / ").presence || pattern.to_s
    end

    def initialize(url)
      @url = url.to_s
    end

    def pattern
      path = path_without_query
      return path if path.blank?

      recognize_and_placeholderize(path) || fallback_normalize(path)
    end

    private

    def path_without_query
      raw = @url.to_s.strip
      return "" if raw.blank?

      uri_path = URI.parse(raw).path
      return uri_path if uri_path.present?

      raw.split("?", 2).first
    rescue URI::InvalidURIError
      raw.split("?", 2).first
    end

    def recognize_and_placeholderize(path)
      recognized = Rails.application.routes.recognize_path(path)
      # Catch-all / missing-resource routes collapse too aggressively for analytics grouping.
      return nil if recognized[:controller].to_s == "missing_resources"

      path_params = recognized.except(:controller, :action, :format)
      return path if path_params.empty?
      return nil if catch_all_path_param?(path_params)

      placeholders = path_params.keys.index_with { |key| ":#{key}" }
      Rails.application.routes.url_helpers.url_for(
        recognized.merge(placeholders).merge(only_path: true)
      )
    rescue ActionController::RoutingError, ArgumentError, ActionController::UrlGenerationError
      nil
    end

    def catch_all_path_param?(path_params)
      path_params.size == 1 && path_params[:path].to_s.include?("/")
    end

    def fallback_normalize(path)
      path.split("/").map do |segment|
        next segment if segment.blank?
        next ":id" if ID_LIKE_SEGMENT.match?(segment)

        segment
      end.join("/")
    end
  end
end
