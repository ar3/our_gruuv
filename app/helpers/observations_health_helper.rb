# frozen_string_literal: true

module ObservationsHealthHelper
  RECENCY_STATUS_COPY = {
    "green" => "Healthy",
    "yellow" => "Stale",
    "red" => "Never"
  }.freeze

  RECENCY_DAYS = Observations::HealthRecency::RECENCY_DAYS

  def observations_health_filter_label(value)
    option = @available_manager_filter_options.find { |(_label, option_value)| option_value.to_s == value.to_s }
    option ? option.first : "Unknown filter"
  end

  def observations_health_recency_copy(status)
    RECENCY_STATUS_COPY[status.to_s] || status.to_s.humanize
  end

  def observations_health_recency_caption(section)
    count = section["observations_count"].to_i
    label = "#{count} #{'OGO'.pluralize(count)}"
    return label if count.zero?

    last_at = section["last_published_at"]
    return label if last_at.blank?

    parsed = Time.zone.parse(last_at)
    return label unless parsed

    "#{label}, last #{time_ago_in_words(parsed)} ago"
  end

  def observations_health_recency_alert_class(status)
    case status.to_s
    when "green"
      "alert alert-success mb-0 py-2"
    when "yellow"
      "alert alert-warning mb-0 py-2"
    else
      "alert alert-danger mb-0 py-2"
    end
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
      "Spotlight Healthy / Ok / Needs attention uses only Given and Received (worst of the two).",
      "Given: green if a non-journal OGO was published in the last #{RECENCY_DAYS} days; yellow if older; red if never.",
      "Received: same recency rules for published OGOs where they are an observee (self-journals count only when they are the observee).",
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

  def observations_health_recency_popover_content(column_label)
    content_tag(:div, class: "small") do
      safe_join([
        content_tag(:p, class: "mb-2") do
          "#{column_label} uses published OGOs only (not drafts or journals excluded by the Given/Received rules)."
        end,
        content_tag(:ul, class: "mb-0 ps-3") do
          safe_join([
            content_tag(:li, "Healthy — published in the last #{RECENCY_DAYS} days.", class: "mb-1"),
            content_tag(:li, "Stale — last publish was more than #{RECENCY_DAYS} days ago.", class: "mb-1"),
            content_tag(:li, "Never — no qualifying published OGOs yet.", class: "mb-0")
          ])
        end
      ])
    end
  end
end
