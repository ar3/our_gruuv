module GoalsHealthHelper
  STATUS_COPY = {
    healthy: "Healthy",
    ok: "Ok",
    concerning: "Needs attention"
  }.freeze

  BUCKET_KEYS = %i[associated unassociated child].freeze

  def goals_health_alert_class(status)
    case status
    when :healthy
      "alert alert-success mb-0 py-2"
    when :ok
      "alert alert-warning mb-0 py-2"
    else
      "alert alert-danger mb-0 py-2"
    end
  end

  # When any goal bucket for the row is healthy, non-healthy buckets use info (not warning/danger)
  # so the row reads as "overall on track" with neutral detail for other groupings.
  def goals_health_row_bucket_alert_class(row, bucket_key)
    any_healthy = BUCKET_KEYS.any? { |k| row[k][:status] == :healthy }
    status = row[bucket_key][:status]

    if any_healthy
      return goals_health_alert_class(:healthy) if status == :healthy

      "alert alert-info mb-0 py-2"
    else
      goals_health_alert_class(status)
    end
  end

  def goals_health_filter_label(value)
    option = @available_manager_filter_options.find { |(_label, option_value)| option_value.to_s == value.to_s }
    option ? option.first : "Unknown filter"
  end

  def goals_health_status_copy(status)
    STATUS_COPY[status.to_sym] || status.to_s.humanize
  end

  def goals_health_definition_lines
    [
      "Healthy — Completed a goal in the last #{Goals::HealthThresholds::COMPLETED_RECENTLY_DAYS} days, or every active goal has a check-in in the last #{Goals::HealthThresholds::CHECK_IN_RECENCY_DAYS} days.",
      "Ok — Has active goals, but not every active goal has a recent check-in.",
      "Needs attention — No active goals and no goal completed in the last #{Goals::HealthThresholds::COMPLETED_RECENTLY_DAYS} days."
    ]
  end

  def goals_health_cell_popover_title(label)
    "#{label} by privacy"
  end

  def goals_health_cell_popover_content(goals)
    header = content_tag(:thead) do
      content_tag(:tr) do
        content_tag(:th, "Privacy") +
          content_tag(:th, "Draft", class: "text-end") +
          content_tag(:th, "Active", class: "text-end") +
          content_tag(:th, class: "text-end") do
            content_tag(:i, "", class: "bi bi-trophy")
          end
      end
    end

    body = content_tag(:tbody) do
      goals_health_popover_privacy_groups.map do |row|
        counts = goals_health_counts_for_privacy_levels(goals, row[:privacy_levels])
        content_tag(:tr) do
          content_tag(:td, row[:label]) +
            content_tag(:td, counts[:draft].to_s, class: "text-end") +
            content_tag(:td, "#{counts[:active_healthy]} of #{counts[:active_total]}", class: "text-end") +
            content_tag(:td, "#{counts[:completed_recent]} of #{counts[:completed_total]}", class: "text-end")
        end
      end.join.html_safe
    end

    caption = content_tag(:caption, class: "text-muted small mt-2") do
      content_tag(:div, "Active = [w/ recent check-ins] of [active]") +
        content_tag(:div) do
          "#{content_tag(:i, '', class: 'bi bi-trophy')} = [#{content_tag(:i, '', class: 'bi bi-check-circle-fill')} in last #{Goals::HealthThresholds::COMPLETED_RECENTLY_DAYS}] of [completed]".html_safe
        end
    end

    content_tag(:table, header + body + caption, class: "table table-sm mb-0")
  end

  def goals_health_popover_privacy_groups
    [
      { label: "Private", privacy_levels: %w[only_creator only_creator_and_owner] },
      { label: "Shared w/ Mgrs", privacy_levels: %w[only_creator_owner_and_managers] },
      { label: "Public", privacy_levels: %w[everyone_in_company] }
    ]
  end

  def goals_health_counts_for_privacy_levels(goals, privacy_levels)
    levels = Array(privacy_levels).map(&:to_s)
    privacy_goals = goals.select { |goal| levels.include?(goal.privacy_level.to_s) }
    active_cutoff_week = Goals::HealthThresholds.check_in_recency_cutoff_week_start
    completed_cutoff = Goals::HealthThresholds.completed_recently_cutoff

    active_goals = privacy_goals.select { |goal| goal.started_at.present? && goal.completed_at.nil? }
    completed_goals = privacy_goals.select { |goal| goal.completed_at.present? }

    {
      draft: privacy_goals.count { |goal| goal.started_at.nil? && goal.completed_at.nil? },
      active_healthy: active_goals.count { |goal| goals_health_active_recent?(goal, active_cutoff_week) },
      active_total: active_goals.count,
      completed_recent: completed_goals.count { |goal| goal.completed_at && goal.completed_at >= completed_cutoff },
      completed_total: completed_goals.count
    }
  end

  def goals_health_active_recent?(goal, cutoff_week)
    latest_check_in = goal.goal_check_ins.max_by(&:check_in_week_start)
    latest_check_in&.check_in_week_start.present? && latest_check_in.check_in_week_start >= cutoff_week
  end
end
