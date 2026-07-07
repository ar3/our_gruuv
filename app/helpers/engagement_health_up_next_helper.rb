# frozen_string_literal: true

module EngagementHealthUpNextHelper
  def up_next_gruuv_health_pill_class(status)
    case status
    when EngagementHealth::HEALTHY
      "border border-success text-success bg-transparent"
    when EngagementHealth::WARNING
      "border border-warning text-warning bg-transparent"
    when EngagementHealth::NEEDS_ATTENTION
      "border border-danger text-danger bg-transparent"
    else
      "border border-secondary text-secondary bg-transparent"
    end
  end

  def up_next_gruuv_health_pill_label(status)
    return "Pending" if status.blank?

    EngagementHealth::STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def up_next_workflow_completion_icon(complete)
    if complete
      tag.i(class: "bi bi-check-circle-fill text-success", aria: { hidden: true })
    else
      tag.i(class: "bi bi-circle text-muted", aria: { hidden: true })
    end
  end
end
