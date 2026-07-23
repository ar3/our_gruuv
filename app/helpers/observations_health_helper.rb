# frozen_string_literal: true

module ObservationsHealthHelper
  OGO_HEALTHY_DAYS = EngagementHealth::Thresholds::OGO_HEALTHY_WITHIN_DAYS
  OGO_NEEDS_ATTENTION_DAYS = EngagementHealth::Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS

  def observations_health_filter_label(value)
    option = @available_manager_filter_options.find { |(_label, option_value)| option_value.to_s == value.to_s }
    option ? option.first : "Unknown filter"
  end

  def observations_health_status_copy(status)
    EngagementHealth::STATUS_LABELS.fetch(status.to_s) { status.to_s.humanize }
  end

  # Backward-compatible alias used by older specs/call sites.
  def observations_health_recency_copy(status)
    case status.to_s
    when "green" then EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::HEALTHY)
    when "yellow" then EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::WARNING)
    when "red" then EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::NEEDS_ATTENTION)
    else
      observations_health_status_copy(status)
    end
  end

  def observations_health_status_caption(section)
    count = section["observations_count"].to_i
    last_at = section["last_published_at"]
    never = section["never"] == true || (last_at.blank? && count.zero?)

    if never && count.zero?
      return "Never published"
    end

    parts = []
    parts << "#{count} #{'OGO'.pluralize(count)}" if count.positive?

    if last_at.present?
      parsed = Time.zone.parse(last_at.to_s)
      parts << "last #{time_ago_in_words(parsed)} ago" if parsed
    end

    parts.join(", ").presence || "No data yet"
  end

  def observations_health_recency_caption(section)
    observations_health_status_caption(section)
  end

  def observations_health_status_alert_class(status)
    case status.to_s
    when EngagementHealth::HEALTHY, "green"
      "alert alert-success mb-0 py-2"
    when EngagementHealth::WARNING, "yellow"
      "alert alert-warning mb-0 py-2"
    else
      "alert alert-danger mb-0 py-2"
    end
  end

  def observations_health_recency_alert_class(status)
    observations_health_status_alert_class(status)
  end

  def observations_health_band_alert_class(band)
    case band.to_s
    when "healthy"
      "alert alert-success mb-0 py-2"
    when "no_data"
      "alert alert-secondary mb-0 py-2"
    else
      "alert alert-warning mb-0 py-2"
    end
  end

  def observations_health_definition_lines
    [
      "Spotlight Healthy / Warning / Needs Attention uses only Given and Received (worst of the two).",
      "Given: Healthy if a non-journal OGO was published in the last #{OGO_HEALTHY_DAYS} days; Warning if #{OGO_HEALTHY_DAYS + 1}–#{OGO_NEEDS_ATTENTION_DAYS - 1}; Needs Attention if ≥ #{OGO_NEEDS_ATTENTION_DAYS} days or never.",
      "Received: same Gruuv Health rules for published OGOs where they are an observee (self-journals count only when they are the observee).",
      "Kudos mix: ratio of kudos-style vs constructive OGOs they authored (healthy target about #{Insights::ObservationsRatingHealth::KUDOS_CONSTRUCTIVE_HEALTHY_RATIO_LABEL}).",
      "Rating intensity: ratio of everyday (Solid + Misaligned) to extreme (Exceptional + Concerning) ratings on OGOs they authored (healthy target about 3:1)."
    ]
  end

  def observations_health_popover_data(title, html_content)
    {
      "data-bs-toggle" => "popover",
      "data-bs-trigger" => "hover focus",
      "data-bs-placement" => "auto",
      "data-bs-html" => "true",
      "data-bs-title" => title,
      "data-bs-content" => html_content
    }
  end

  def observations_health_cell_attrs(alert_class, popover_title, popover_content)
    observations_health_popover_data(popover_title, popover_content).merge(class: alert_class)
  end

  def observations_health_kudos_mix_popover_content(row)
    Insights::ObservationsRatingHealthCopy.kudos_constructive_html(
      band: row[:kudos_mix]["band"],
      subject_name: row[:person].display_name
    )
  end

  def observations_health_rating_intensity_popover_content(row)
    Insights::ObservationsRatingHealthCopy.rating_intensity_html(
      band: row[:rating_intensity]["band"],
      subject_name: row[:person].display_name
    )
  end

  def observations_health_status_popover_content(column_label)
    content_tag(:div, class: "small") do
      safe_join([
        content_tag(:p, class: "mb-2") do
          "#{column_label} uses Gruuv Health (same rules as My One Thing Overview) for published OGOs only."
        end,
        content_tag(:ul, class: "mb-0 ps-3") do
          safe_join([
            content_tag(:li, "Healthy — published in the last #{OGO_HEALTHY_DAYS} days.", class: "mb-1"),
            content_tag(
              :li,
              "Warning — last publish was #{OGO_HEALTHY_DAYS + 1}–#{OGO_NEEDS_ATTENTION_DAYS - 1} days ago.",
              class: "mb-1"
            ),
            content_tag(
              :li,
              "Needs Attention — last publish was ≥ #{OGO_NEEDS_ATTENTION_DAYS} days ago, or never.",
              class: "mb-0"
            )
          ])
        end
      ])
    end
  end

  def observations_health_recency_popover_content(column_label)
    observations_health_status_popover_content(column_label)
  end
end
