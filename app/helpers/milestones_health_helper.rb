# frozen_string_literal: true

module MilestonesHealthHelper
  STATUS_COPY = {
    healthy: "Healthy",
    ok: "Warning",
    concerning: "Needs Attention"
  }.freeze

  STATUS_ICON = {
    healthy: "bi-check-circle-fill text-success",
    ok: "bi-exclamation-circle-fill text-warning",
    concerning: "bi-x-circle-fill text-danger"
  }.freeze

  def milestones_health_filter_label(value)
    option = @available_manager_filter_options.find { |(_label, option_value)| option_value.to_s == value.to_s }
    option ? option.first : "Unknown filter"
  end

  def milestones_health_status_copy(status)
    STATUS_COPY[status.to_sym] || status.to_s.humanize
  end

  def milestones_health_status_icon_class(status)
    STATUS_ICON[status.to_sym] || "bi-question-circle text-muted"
  end

  def milestones_health_definition_lines
    [
      "Milestones uses Gruuv Health (same rules as 1:1 Hub Overview).",
      "Required abilities come from the teammate’s current position and active assignments.",
      "Healthy — required milestone earned, or an active goal is attached.",
      "Warning — earlier milestone only, or only a draft goal attached.",
      "Needs Attention — no milestone and no goal on a required ability. No required abilities is vacuously Healthy."
    ]
  end

  def milestones_health_status_line_text_class(eh_status)
    case eh_status
    when EngagementHealth::HEALTHY then "text-success"
    when EngagementHealth::WARNING then "text-warning"
    else "text-danger"
    end
  end

  def milestones_health_attention_html(row)
    if row[:empty_reason].to_s == "no_required_abilities_vacuously_healthy"
      return content_tag(:div, "No required abilities — vacuously Healthy.")
    end

    items = Array(row[:attention_items])
    if items.empty?
      return content_tag(:div, "All required abilities look Healthy.")
    end

    parts = items.map do |item|
      name_link = link_to(
        item[:name],
        organization_teammate_ability_path(@organization, row[:teammate], item[:entity_id]),
        class: "text-decoration-none"
      )
      content_tag(:div, class: "mb-1") do
        safe_join([
          name_link,
          content_tag(:span, " — #{EngagementHealth::STATUS_LABELS.fetch(item[:status])} (#{item[:reason]})", class: "text-muted")
        ])
      end
    end

    safe_join(parts)
  end
end
