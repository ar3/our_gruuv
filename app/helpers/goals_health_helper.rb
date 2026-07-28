# frozen_string_literal: true

module GoalsHealthHelper
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

  GOAL_CONFIDENCE_HEALTHY_DAYS = EngagementHealth::Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS
  GOAL_CONFIDENCE_NEEDS_ATTENTION_DAYS = EngagementHealth::Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS
  COMPLETED_GOAL_WINDOW_DAYS = EngagementHealth::Thresholds::COMPLETED_GOAL_WINDOW_DAYS

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

  def goals_health_filter_label(value)
    option = @available_manager_filter_options.find { |(_label, option_value)| option_value.to_s == value.to_s }
    option ? option.first : "Unknown filter"
  end

  def goals_health_status_copy(status)
    STATUS_COPY[status.to_sym] || status.to_s.humanize
  end

  def goals_health_status_icon_class(status)
    STATUS_ICON[status.to_sym] || "bi-question-circle text-muted"
  end

  def goals_health_definition_lines
    [
      "Goal Confidence uses Gruuv Health (same rules as 1:1 Hub Overview).",
      "Scored goals: active goals plus goals completed in the last #{COMPLETED_GOAL_WINDOW_DAYS} days (drafts are not scored).",
      "Healthy — checked within #{GOAL_CONFIDENCE_HEALTHY_DAYS} days. Warning — #{GOAL_CONFIDENCE_HEALTHY_DAYS + 1}–#{GOAL_CONFIDENCE_NEEDS_ATTENTION_DAYS - 1} days. Needs Attention — ≥ #{GOAL_CONFIDENCE_NEEDS_ATTENTION_DAYS} days, never, or no scored goals."
    ]
  end

  def goals_health_status_line_label(eh_status)
    EngagementHealth::STATUS_LABELS.fetch(eh_status)
  end

  def goals_health_status_line_text_class(eh_status)
    case eh_status
    when EngagementHealth::HEALTHY then "text-success"
    when EngagementHealth::WARNING then "text-warning"
    else "text-danger"
    end
  end

  def goals_health_attachment_html(row)
    entry = row[:attachments]
    teammate = row[:teammate]
    parts = []

    if entry.active_with_attachments_count.zero?
      parts << content_tag(:div, "No active goals are attached to assignments, abilities, values, or prompts.")
    else
      attached_bits = entry.type_groups.map { |group| goals_health_type_group_html(group, teammate) }
      prefix = "#{entry.active_with_attachments_count} #{'active goal'.pluralize(entry.active_with_attachments_count)} attached to"
      parts << content_tag(:div) do
        safe_join([prefix, ": ", safe_join(attached_bits, ", "), "."])
      end
    end

    if entry.active_child_count.positive?
      parts << content_tag(:div) do
        "#{entry.active_child_count} #{'active goal'.pluralize(entry.active_child_count)} #{entry.active_child_count == 1 ? 'is a' : 'are'} child #{'goal'.pluralize(entry.active_child_count)}."
      end
    end

    safe_join(parts)
  end

  def goals_health_type_group_html(group, teammate)
    if group.sole
      link_to(
        group.sole.name,
        goals_health_associable_path(teammate, group.sole),
        class: "text-decoration-none"
      )
    else
      "#{group.count} #{group.plural_label}"
    end
  end

  def goals_health_associable_path(teammate, sole)
    case sole.associable_type
    when "Assignment"
      organization_teammate_assignment_path(@organization, teammate, sole.id)
    when "Ability"
      organization_teammate_ability_path(@organization, teammate, sole.id)
    when "Aspiration"
      organization_teammate_aspiration_path(@organization, teammate, sole.id)
    when "Prompt"
      edit_organization_prompt_path(@organization, sole.id)
    end
  end
end
