# frozen_string_literal: true

module OgScorecardHelper
  def og_scorecard_filter_params
    {
      department_id: Array(params[:department_id]).reject(&:blank?).presence,
      manager_id: Array(params[:manager_id]).reject(&:blank?).presence
    }.compact
  end

  def og_scorecard_path_with_filters(**extra)
    organization_insights_og_scorecard_path(
      @organization,
      **og_scorecard_filter_params,
      timeframe: params[:timeframe].presence,
      from: params[:from].presence,
      to: params[:to].presence,
      **extra
    )
  end

  def og_scorecard_filters_active?
    og_scorecard_filter_params.any?
  end

  def og_scorecard_filter_pill_labels(departments:, manager_options:, selected_department_ids:, selected_manager_ids:)
    labels = []

    selected_department_ids.each do |id|
      labels << if id == 'none'
                  'No department'
                else
                  departments.find { |department| department.id.to_s == id.to_s }&.name
                end
    end

    selected_manager_ids.reject { |id| id == 'everyone' }.each do |value|
      label = manager_options.find { |_name, option_value| option_value == value }&.first
      labels << label if label.present?
    end

    labels.compact
  end

  def og_scorecard_metric_label(row)
    label = row[:label]
    hint = row[:threshold_hint]
    return label if hint.blank?

    safe_join([label, content_tag(:span, " (#{hint})", class: 'text-muted')], '')
  end

  # Status-colored icon shown before a Gruuv Health row label. On hover it
  # explains the shared three-state model and what this specific row counts.
  def og_scorecard_gruuv_status_icon(status, category)
    return if status.blank?

    icon_class = case status
                 when EngagementHealth::HEALTHY then 'bi-check-circle-fill text-success'
                 when EngagementHealth::WARNING then 'bi-exclamation-circle-fill text-warning'
                 when EngagementHealth::NEEDS_ATTENTION then 'bi-exclamation-triangle-fill text-danger'
                 else 'bi-circle text-secondary'
                 end
    state = EngagementHealth::STATUS_LABELS.fetch(status, status.to_s.humanize)
    concept = EngagementHealth::CATEGORY_LABELS.fetch(category, category.to_s.humanize)
    explanation = Insights::OgScorecard::MetricRegistry.gruuv_threshold_hint(category, status)
    tooltip = "To keep things clear, every teammate is always in one of three states — Healthy, Warning, or " \
              "Needs Attention — for observations, check-ins, and goals. This row shows all teammates in the " \
              "#{state} state for #{concept}, meaning: #{explanation}."

    content_tag(
      :i,
      '',
      class: "bi #{icon_class} me-1 og-scorecard-gruuv-icon",
      tabindex: 0,
      role: 'img',
      'aria-label': "#{state}: #{tooltip}",
      data: { 'bs-toggle': 'tooltip', 'bs-placement': 'top', 'bs-title': tooltip }
    )
  end
end
