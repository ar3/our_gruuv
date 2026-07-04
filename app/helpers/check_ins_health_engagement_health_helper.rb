# frozen_string_literal: true

module CheckInsHealthEngagementHealthHelper
  ENGAGEMENT_HEALTH_BAR_ORDER = [
    EngagementHealth::NEEDS_ATTENTION,
    EngagementHealth::AT_RISK,
    EngagementHealth::HEALTHY
  ].freeze

  ENGAGEMENT_HEALTH_BAR_CSS = {
    EngagementHealth::NEEDS_ATTENTION => "bg-danger",
    EngagementHealth::AT_RISK => "bg-warning",
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
    when EngagementHealth::AT_RISK
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
end
