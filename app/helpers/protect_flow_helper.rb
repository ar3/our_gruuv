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
end
