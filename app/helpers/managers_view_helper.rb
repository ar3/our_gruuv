# frozen_string_literal: true

module ManagersViewHelper
  GOALS_AXIS_STATUS_COPY = {
    healthy: "Healthy",
    ok: "Need update",
    concerning: "Need attention"
  }.freeze

  OGO_AXIS_STATUS_COPY = {
    "green" => "Healthy",
    "yellow" => "Need update",
    "red" => "Need attention"
  }.freeze

  def managers_view_axis_status_icon(status, kind:)
    normalized = normalize_managers_view_axis_status(status, kind: kind)
    copy = managers_view_axis_status_copy(normalized, kind: kind)
    icon_class, text_class = managers_view_axis_status_styles(normalized)

    content_tag(
      :span,
      class: "d-inline-flex align-items-center gap-1",
      title: copy,
      "data-bs-toggle" => "tooltip",
      "data-bs-placement" => "top"
    ) do
      safe_join([
        content_tag(:i, "", class: "bi #{icon_class} #{text_class}", "aria-hidden" => "true"),
        content_tag(:span, copy, class: "visually-hidden")
      ])
    end
  end

  def managers_view_axis_status_copy(status, kind:)
    normalized = normalize_managers_view_axis_status(status, kind: kind)
    case kind
    when :goals
      GOALS_AXIS_STATUS_COPY.fetch(normalized, normalized.to_s.humanize)
    when :ogos
      OGO_AXIS_STATUS_COPY.fetch(normalized, normalized.to_s.humanize)
    else
      normalized.to_s.humanize
    end
  end

  def managers_view_check_in_actions_label(count)
    action_word = count == 1 ? "Action" : "Actions"
    "Complete #{count} Check-In #{action_word}"
  end

  def managers_view_ogo_30d_tooltip
    "Count of published OGOs in the last #{Observations::HealthRecency::RECENCY_DAYS} days."
  end

  private

  def normalize_managers_view_axis_status(status, kind:)
    case kind
    when :goals
      status.to_sym
    when :ogos
      status.presence&.to_s || "red"
    else
      status
    end
  end

  def managers_view_axis_status_styles(normalized)
    case normalized.to_s
    when "healthy", "green"
      ["bi-check-circle-fill", "text-success"]
    when "ok", "yellow"
      ["bi-exclamation-circle-fill", "text-warning"]
    else
      ["bi-x-circle-fill", "text-danger"]
    end
  end
end
