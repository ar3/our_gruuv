# frozen_string_literal: true

module ProtectFlowHelper
  def protect_flow_status_badge_class(status)
    case status
    when EngagementHealth::HEALTHY
      "text-bg-success"
    when EngagementHealth::WARNING
      "text-bg-warning"
    when EngagementHealth::NEEDS_ATTENTION
      "text-bg-danger"
    else
      "text-bg-secondary"
    end
  end

  def protect_flow_status_label(status)
    return "Pending" if status.blank?

    EngagementHealth::STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def protect_flow_week_label(week_start)
    Date.parse(week_start.to_s).strftime("%b %-d, %Y")
  rescue ArgumentError, TypeError
    week_start.to_s
  end

  # Renders an opportunity sentence hash with an inline action link (no bullet lists).
  def protect_flow_opportunity_sentence(opportunity)
    return if opportunity.blank?
    return content_tag(:span, opportunity.to_s) unless opportunity.is_a?(Hash)

    before = opportunity[:before].to_s
    link_text = opportunity[:link_text]
    link_path = opportunity[:link_path]
    after = opportunity[:after].to_s
    method = opportunity[:link_method]

    parts = []
    parts << before if before.present?
    if link_text.present? && link_path.present?
      link_opts = { class: "link-primary" }
      link_opts[:data] = { turbo_method: method } if method.present?
      parts << link_to(link_text, link_path, link_opts)
    elsif link_text.present?
      parts << link_text
    end
    parts << after if after.present?
    safe_join(parts)
  end
end
