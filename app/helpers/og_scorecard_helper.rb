# frozen_string_literal: true

module OgScorecardHelper
  DISPLAY_VALUES = 'values'
  DISPLAY_PERCENT = 'percent'
  # Headcount row is the denominator; percent-of-itself is not useful.
  PERCENT_DISPLAY_EXCLUDED_KEYS = %w[active_teammates].freeze

  def og_scorecard_display_mode
    params[:display].to_s == DISPLAY_PERCENT ? DISPLAY_PERCENT : DISPLAY_VALUES
  end

  def og_scorecard_percent_mode?
    og_scorecard_display_mode == DISPLAY_PERCENT
  end

  def og_scorecard_percent_display_eligible?(row)
    row[:supports_percent] && PERCENT_DISPLAY_EXCLUDED_KEYS.exclude?(row[:key].to_s)
  end

  def og_scorecard_filter_params
    {
      department_id: Array(params[:department_id]).reject(&:blank?).presence,
      manager_id: Array(params[:manager_id]).reject(&:blank?).presence,
      display: (DISPLAY_PERCENT if og_scorecard_percent_mode?)
    }.compact
  end

  def og_scorecard_path_with_filters(**extra)
    display = extra.key?(:display) ? extra[:display] : og_scorecard_display_mode
    path_params = {
      **og_scorecard_filter_params.except(:display),
      timeframe: params[:timeframe].presence,
      from: params[:from].presence,
      to: params[:to].presence,
      **extra.except(:display)
    }
    path_params[:display] = DISPLAY_PERCENT if display.to_s == DISPLAY_PERCENT
    organization_insights_og_scorecard_path(@organization, **path_params.compact)
  end

  def og_scorecard_filters_active?
    og_scorecard_filter_params.except(:display).any?
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

  # Concept group header → corresponding Insights health page (Teammates has none).
  def og_scorecard_group_title(title)
    path = case title
           when 'Observations' then organization_observations_health_path(@organization)
           when 'Check-ins' then organization_check_ins_health_path(@organization)
           when 'Ability Milestones' then organization_milestones_health_path(@organization)
           when 'Goals' then organization_goals_health_path(@organization)
           end
    return title if path.blank?

    link_to path, class: 'text-decoration-none text-body' do
      safe_join(
        [
          title,
          ' ',
          content_tag(:i, '', class: 'bi bi-heart-pulse', 'aria-hidden': true)
        ]
      )
    end
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

  def og_scorecard_six_week_avg_display(row)
    avg = row[:six_week_avg]
    unless og_scorecard_percent_mode? && og_scorecard_percent_display_eligible?(row)
      return avg.nil? ? '—' : avg
    end

    values = Array(row[:weekly_values]).last(6)
    actives = Array(row[:weekly_active_counts]).last(6)
    percentages = values.zip(actives).filter_map do |value, active|
      next if active.to_i.zero?

      value.to_f / active * 100.0
    end
    return '—' if percentages.empty?

    "#{percentages.sum.fdiv(percentages.size).round}%"
  end

  def og_scorecard_weekly_cell_display(value, active_count, row:)
    if og_scorecard_percent_mode? && og_scorecard_percent_display_eligible?(row)
      og_scorecard_percent_of_teammates(value, active_count)
    else
      value
    end
  end

  def og_scorecard_percent_of_teammates(value, active_count)
    return '—' if active_count.to_i.zero?

    "#{(value.to_f / active_count * 100.0).round}%"
  end

  def og_scorecard_cell_detail_tooltip(value, active_count)
    active = active_count.to_i
    if active.zero?
      "#{value} of 0 teammates (—)"
    else
      pct = (value.to_f / active * 100.0).round
      "#{value} of #{active} teammates (#{pct}%)"
    end
  end

  def og_scorecard_weekly_cell_tag_attrs(value, active_count, row:, status:)
    attrs = {
      class: ['text-end', og_scorecard_weekly_cell_class(status)].join(' ')
    }
    return attrs unless og_scorecard_percent_display_eligible?(row)

    tooltip = og_scorecard_cell_detail_tooltip(value, active_count)
    attrs.merge(
      tabindex: 0,
      'aria-label': tooltip,
      data: {
        'bs-toggle': 'tooltip',
        'bs-placement': 'top',
        'bs-title': tooltip
      }
    )
  end
end
