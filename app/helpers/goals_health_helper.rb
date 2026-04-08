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
end
