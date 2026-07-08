# frozen_string_literal: true

module CheckInsHealthEngagementHealthHelper
  ACTION_SLOTS_SUMMARY_MAX_WIDTH_PX = 200
  ACTION_SLOTS_SUMMARY_BAR_HEIGHT_PX = 10

  ENGAGEMENT_HEALTH_BAR_ORDER = [
    EngagementHealth::NEEDS_ATTENTION,
    EngagementHealth::WARNING,
    EngagementHealth::HEALTHY
  ].freeze

  ENGAGEMENT_HEALTH_BAR_CSS = {
    EngagementHealth::NEEDS_ATTENTION => "bg-danger",
    EngagementHealth::WARNING => "bg-warning",
    EngagementHealth::HEALTHY => "bg-success"
  }.freeze

  def check_ins_health_engagement_items(records, entity_type: nil)
    CheckInsHealthEngagementHealthSupport.items_for(records, entity_type: entity_type)
  end

  def check_ins_health_engagement_category_rollup(records)
    CheckInsHealthEngagementHealthSupport.category_rollup(records)
  end

  def check_ins_health_engagement_status_counts(items)
    CheckInsHealthEngagementHealthSupport.status_counts(items)
  end

  def check_ins_health_engagement_stacked_bar_segments(status_counts)
    total = status_counts.values.sum.to_f
    return [] if total.zero?

    ENGAGEMENT_HEALTH_BAR_ORDER.filter_map do |status|
      count = status_counts[status].to_i
      next if count.zero?

      {
        status: status,
        pct: (count / total * 100).round(1),
        count: count,
        css: ENGAGEMENT_HEALTH_BAR_CSS.fetch(status)
      }
    end
  end

  def check_ins_health_engagement_segment_tooltip(segment, total, object_name)
    label = EngagementHealth::STATUS_LABELS.fetch(segment[:status])
    "#{segment[:count]} of #{total} required #{object_name} are #{label}"
  end

  def check_ins_health_engagement_status_meaning(status)
    case status
    when EngagementHealth::HEALTHY
      "every required item finalized within #{EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS} days"
    when EngagementHealth::WARNING
      "worst required item finalized #{EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1}–" \
        "#{EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
    when EngagementHealth::NEEDS_ATTENTION
      "any required item ≥ #{EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS} days ago or never finalized"
    else
      status.to_s.humanize
    end
  end

  def check_ins_health_engagement_alert_data(records:, organization:, teammate:)
    if records.blank?
      return {
        all_clear: false,
        message: "No Gruuv Health data yet — use refresh to queue a calculation.",
        url: nil
      }
    end

    if CheckInsHealthEngagementHealthSupport.all_clear?(records)
      return { all_clear: true, message: "Gruuv Health check-ins look good", url: nil }
    end

    worst = CheckInsHealthEngagementHealthSupport.worst_item(records)
    return { all_clear: true, message: "Gruuv Health check-ins look good", url: nil } if worst.blank?

    status_label = EngagementHealth::STATUS_LABELS.fetch(worst.status)
    name = worst.inputs["name"].presence || worst.entity_type.to_s.humanize
    {
      all_clear: false,
      message: "Consider checking in on: #{name} (#{status_label})",
      url: check_ins_health_engagement_item_path(organization: organization, teammate: teammate, item: worst)
    }
  end

  def check_ins_health_engagement_item_path(organization:, teammate:, item:)
    case item.entity_type
    when "Position"
      position_check_in_organization_teammate_path(organization, teammate)
    when "Assignment"
      organization_teammate_assignment_path(organization, teammate, item.entity_id)
    when "Aspiration"
      organization_teammate_aspiration_path(organization, teammate, item.entity_id)
    end
  end

  def check_ins_health_engagement_refreshed_tooltip(records)
    computed_at = CheckInsHealthEngagementHealthSupport.computed_at_for(records)
    computed_at ? "Gruuv Health computed #{time_ago_in_words(computed_at)} ago" : "Gruuv Health has not been computed yet"
  end

  def check_ins_health_action_slots_summary_bar_height_px
    ACTION_SLOTS_SUMMARY_BAR_HEIGHT_PX
  end

  def check_ins_health_action_summary_segments(breakdown)
    [
      [breakdown.healthy_percentage, EngagementHealth::HEALTHY],
      [breakdown.warning_percentage, EngagementHealth::WARNING],
      [breakdown.needs_attention_percentage, EngagementHealth::NEEDS_ATTENTION]
    ]
  end

  def check_ins_health_action_slots_bar_segments(breakdown)
    return [] if breakdown.blank? || breakdown.total_slots.zero?

    check_ins_health_action_summary_segments(breakdown).filter_map do |percentage, status|
      next if percentage.to_f.zero?

      {
        percentage: percentage,
        status: status,
        css: check_ins_health_eh_status_bar_css(status),
        label: "#{percentage}% #{EngagementHealth::STATUS_LABELS.fetch(status)}"
      }
    end
  end

  def check_ins_health_eh_status_bar_css(status)
    CheckInsHealthBarsHelper::EH_STATUS_CSS.fetch(status, "check-in-health-action-anomaly-gray")
  end

  def check_ins_health_action_summary_text_class(status)
    case status
    when EngagementHealth::HEALTHY then "text-success"
    when EngagementHealth::WARNING then "text-warning"
    when EngagementHealth::NEEDS_ATTENTION then "text-danger"
    else "text-muted"
    end
  end

  def check_ins_health_action_popover_html(records:, employee_name:, manager_name:)
    rows = EngagementHealth::ClarityActionMetrics.popover_rows(records)
    return nil if rows.empty?

    render(
      partial: "organizations/check_ins_health/action_slots_popover_table",
      locals: { rows: rows, employee_name: employee_name, manager_name: manager_name }
    ).html_safe
  end
end
