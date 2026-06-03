# frozen_string_literal: true

module AssignmentEnergyAllocationHelper
  def assignment_energy_allocation_total_label(total, over_hundred: false)
    if over_hundred
      "#{total}% (over 100%)"
    else
      "#{total}%"
    end
  end

  def assignment_energy_allocation_alert_class(alert_band)
    case alert_band
    when CheckIns::EnergyAllocationConstants::ALERT_SUCCESS
      'assignment-energy-allocation-panel--success'
    when CheckIns::EnergyAllocationConstants::ALERT_WARNING
      'assignment-energy-allocation-panel--warning'
    when CheckIns::EnergyAllocationConstants::ALERT_DANGER
      'assignment-energy-allocation-panel--danger'
    else
      ''
    end
  end

  def assignment_energy_allocation_reflection_alert_class(alert_band)
    assignment_energy_allocation_alert_class(alert_band)
  end

  # Returns { segments: [{ flex_percent, color, name, value, assignment_id }], unallocated_percent:, over_hundred: }
  def assignment_energy_allocation_bar_layout(segments, total)
    segments = Array(segments)
    return { segments: [], unallocated_percent: 100.0, over_hundred: false } if segments.empty?

    total = total.to_i
    over_hundred = total > 100

    if over_hundred
      weight_sum = segments.sum { |s| s[:value].to_i.positive? ? s[:value].to_i : s[:display_weight].to_i }
      weight_sum = segments.sum { |s| s[:display_weight].to_i } if weight_sum <= 0
      weight_sum = 1 if weight_sum <= 0

      laid_out = segments.map do |segment|
        weight = segment[:value].to_i.positive? ? segment[:value].to_i : segment[:display_weight].to_i
        {
          assignment_id: segment[:assignment_id],
          name: segment[:name],
          value: segment[:value].to_i,
          color: segment[:color],
          flex_percent: (weight.to_f / weight_sum * 100.0).round(4)
        }
      end

      return { segments: laid_out, unallocated_percent: 0.0, over_hundred: true }
    end

    weight_sum = segments.sum { |s| s[:display_weight].to_i }
    weight_sum = 1 if weight_sum <= 0
    colored_width = [total, 0].max.clamp(0, 100)
    unallocated_percent = (100.0 - colored_width).round(4)

    laid_out = segments.map do |segment|
      share = segment[:display_weight].to_i / weight_sum.to_f
      {
        assignment_id: segment[:assignment_id],
        name: segment[:name],
        value: segment[:value].to_i,
        color: segment[:color],
        flex_percent: (share * colored_width).round(4)
      }
    end

    { segments: laid_out, unallocated_percent: unallocated_percent, over_hundred: false }
  end

  def assignment_energy_allocation_finalization_row_data(check_in)
    tenure = check_in.assignment_tenure
    forecast = tenure&.anticipated_energy_percentage
    forecast_int = forecast.present? ? forecast.to_i : nil

    actual = nil
    if check_in.open? && check_in.employee_completed? && check_in.actual_energy_percentage.present?
      val = check_in.actual_energy_percentage.to_i
      actual = val if val.positive?
    end

    left_value = if actual.present?
                   actual
                 else
                   forecast_int
                 end

    initial_updated =
      if check_in.ready_for_finalization?
        (check_in.actual_energy_percentage.presence || forecast).to_i
      else
        left_value || 0
      end

    {
      assignment_id: check_in.assignment_id,
      assignment_title: check_in.assignment.title,
      current_forecast: forecast_int,
      employee_actual: actual,
      initial_updated_forecast: initial_updated
    }
  end

  def assignment_energy_allocation_legend_html(legend_entries)
    return '' if legend_entries.blank?

    safe_join(
      legend_entries.map do |entry|
        content_tag(
          :div,
          class: 'assignment-energy-allocation-legend-item'
        ) do
          safe_join([
            content_tag(:span, '', class: 'assignment-energy-allocation-legend-swatch', style: "background-color: #{entry[:color]};"),
            content_tag(:span, entry[:name], class: 'ms-1')
          ])
        end
      end
    )
  end
end
