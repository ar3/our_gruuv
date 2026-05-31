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
end
