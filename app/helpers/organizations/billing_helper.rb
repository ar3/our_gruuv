# frozen_string_literal: true

module Organizations::BillingHelper
  def invoice_status_badge_class(invoice)
    case invoice.status
    when "open" then "text-bg-warning"
    when "waived" then "text-bg-info"
    when "processing" then "text-bg-primary"
    when "paid" then "text-bg-success"
    when "failed" then "text-bg-danger"
    when "refunded" then "text-bg-secondary"
    else "text-bg-secondary"
    end
  end

  def billing_list_status_badge_class(status)
    case status.to_s
    when "Due" then "text-bg-warning"
    when "Paid" then "text-bg-success"
    when "Waived" then "text-bg-info"
    when "Future" then "text-bg-secondary"
    else "text-bg-secondary"
    end
  end

  # Plain-text Value-page outcome sentence + "Which is valued at $X" for popovers.
  def billing_value_outcome_popover(key:, teammate_count:, activity_count:, value_sum:, company_name:)
    teammates = number_with_delimiter(teammate_count)
    activities = number_with_delimiter(activity_count)
    sentence =
      case key.to_sym
      when :stories
        "OG helped #{teammates} teammates Capture #{activities} #{company_name} #{'Story'.pluralize(activity_count)}"
      when :stand
        "OG helped #{teammates} teammates Know where they stand across #{activities} Performance Clarity Check-ins"
      when :growth
        "OG helped #{teammates} teammates be Recognized for demonstrating Growth across #{activities} Milestone achievements awarded"
      when :goals
        "OG helped #{teammates} teammates Communicate Real Progress across #{activities} Goal Confidence Checks"
      when :consultations
        "OG provided #{teammates} teammates with #{activities} completed Consult OG #{'consultation'.pluralize(activity_count)}"
      else
        "OG helped #{teammates} teammates across #{activities} activities"
      end

    "#{sentence}. Which is valued at #{number_to_currency(value_sum)}."
  end

  def billing_extrapolate_count(count, period_progress)
    return nil if period_progress.to_f <= 0

    (count.to_f / period_progress).round
  end

  def billing_extrapolate_money(amount, period_progress)
    return nil if period_progress.to_f <= 0

    (amount.to_f / period_progress).round(2)
  end

  def billing_period_progress_percent(period_progress)
    (period_progress.to_f * 100).round
  end

  # Scale period-native activity to lookback-comparable units for display.
  def billing_scaled_activity_cell(cell, activity_scale)
    scale = activity_scale.to_f
    return cell if cell.nil? || scale <= 0 || (scale - 1.0).abs < 0.0001

    Organizations::Billing::ValueAnalysisTable::Cell.new(
      activity_count: (cell.activity_count.to_f * scale).round,
      teammate_count: (cell.teammate_count.to_f * scale).round,
      value_sum: (cell.value_sum.to_f * scale).round(2)
    )
  end

  def billing_in_progress_activity_popover(key:, cell:, company_name:, period_progress:, activity_scale: 1.0)
    percent = billing_period_progress_percent(period_progress)
    outcome = billing_value_outcome_popover(
      key: key,
      teammate_count: cell.teammate_count,
      activity_count: cell.activity_count,
      value_sum: cell.value_sum,
      company_name: company_name
    )
    extrapolated_activity = billing_extrapolate_count(cell.activity_count, period_progress)
    extrapolated_value = billing_extrapolate_money(cell.value_sum, period_progress)
    extrapolated_teammates = billing_extrapolate_count(cell.teammate_count, period_progress)

    parts = [
      "This period is about #{percent}% complete.",
      outcome
    ]
    if extrapolated_activity && extrapolated_value
      full = billing_value_outcome_popover(
        key: key,
        teammate_count: extrapolated_teammates || cell.teammate_count,
        activity_count: extrapolated_activity,
        value_sum: extrapolated_value,
        company_name: company_name
      )
      parts << "At this pace, by 100% that may be: #{full}"
    end
    if (activity_scale.to_f - 1.0).abs >= 0.0001
      parts << "Activity is scaled to the ~90-day lookback length for comparison."
    end
    parts.join(" ")
  end

  def billing_value_page_pepm_popover(total:, week_count:, teammate_count:, per_employee_week:, pepm:, so_far: false)
    teammates = "#{number_with_delimiter(teammate_count)} active #{'teammate'.pluralize(teammate_count)}"
    so_far_suffix = so_far ? " so far" : ""
    "#{number_to_currency(total)} ÷ #{week_count} #{'week'.pluralize(week_count)} ÷ #{teammates}#{so_far_suffix} = #{number_to_currency(per_employee_week)} weekly (~#{number_to_currency(pepm)} monthly). / EE means per employee per month."
  end

  def billing_in_progress_pepm_popover(total_cell:, period_progress:, full_week_count: nil)
    percent = billing_period_progress_percent(period_progress)
    base = billing_value_page_pepm_popover(
      total: total_cell.value_sum,
      week_count: total_cell.week_count,
      teammate_count: total_cell.teammate_count,
      per_employee_week: total_cell.per_employee_week,
      pepm: total_cell.pepm,
      so_far: true
    )
    extrapolated_total = billing_extrapolate_money(total_cell.value_sum, period_progress)
    # Pace PEPM must use full-period weeks, not so-far week_count (otherwise (~…) is inflated).
    pace_week_count = full_week_count.to_i.positive? ? full_week_count.to_i : total_cell.week_count.to_i
    parts = ["This period is about #{percent}% complete.", base]
    if extrapolated_total && pace_week_count.positive? && total_cell.teammate_count.to_i.positive?
      extrapolated_week = extrapolated_total / pace_week_count / total_cell.teammate_count
      extrapolated_pepm = extrapolated_week * Organizations::Billing::ValueBasedPepm::APPROX_WEEKS_PER_MONTH
      parts << "At this pace, by 100% that may be #{number_to_currency(extrapolated_pepm.round(2))} / EE (#{number_to_currency(extrapolated_total)} across #{pluralize(total_cell.teammate_count, 'active teammate')})."
    end
    parts.join(" ")
  end

  # Weeks spanning the whole period column (for pace PEPM). Nil when the column has no dates.
  def billing_column_full_week_count(column)
    return nil if column.blank? || column.starts_on.blank? || column.ends_on.blank?

    Organizations::Billing::ValueBasedPepm.week_count_for(column.starts_on..column.ends_on)
  end

  def billing_upcoming_activity_popover(key:, cell:, company_name:, starts_on:, ends_on:, activity_scale: 1.0)
    outcome = billing_value_outcome_popover(
      key: key,
      teammate_count: cell.teammate_count,
      activity_count: cell.activity_count,
      value_sum: cell.value_sum,
      company_name: company_name
    )
    parts = [
      "This is an estimated projection of the value #{company_name} will receive during the next period between #{l(starts_on, format: :long)} and #{l(ends_on, format: :long)}.",
      outcome
    ]
    if (activity_scale.to_f - 1.0).abs >= 0.0001
      parts << "Activity is scaled to the ~90-day lookback length for comparison."
    end
    parts.join(" ")
  end

  def billing_upcoming_pepm_popover(total_cell:, company_name:, starts_on:, ends_on:)
    base = billing_value_page_pepm_popover(
      total: total_cell.value_sum,
      week_count: total_cell.week_count,
      teammate_count: total_cell.teammate_count,
      per_employee_week: total_cell.per_employee_week,
      pepm: total_cell.pepm
    )
    "This is an estimated projection of the value #{company_name} will receive during the next period between #{l(starts_on, format: :long)} and #{l(ends_on, format: :long)}. #{base}"
  end

  def billing_column_mode_locals(column, company_name:)
    full_week_count = billing_column_full_week_count(column)
    case column.status
    when :in_progress
      { mode: :in_progress, period_progress: column.period_progress, full_week_count: full_week_count }
    when :upcoming
      {
        mode: :upcoming,
        company_name: company_name,
        starts_on: column.starts_on,
        ends_on: column.ends_on,
        full_week_count: full_week_count
      }
    else
      { mode: :complete, full_week_count: full_week_count }
    end
  end

  def billing_invoice_pepm_popover(invoice)
    discount = OrganizationBillingSetting::DISCOUNTS.fetch(invoice.cadence, 0.0)
    if discount.positive?
      percent = (discount * 100).to_i
      "We round down to the nearest $0.50 and apply the #{percent}% #{invoice.cadence} cadence discount."
    else
      "We round down to the nearest $0.50. Monthly cadence has no discount."
    end
  end

  # Why PEPM for the upcoming period comes from the prior ~90-day lookback.
  def billing_invoice_value_lookback_popover
    "Transparency. Clarity. Fairness. That leads to Growth. That's the OG Way. " \
      "We aim for it to show up in our values, in our support, in our software, and in this case; in our cost structure. " \
      "When OG helps more, we charge more… In a way you can see and trust. " \
      "We look at the last ~90 days of value delivered. However we performed then, we assume we'll keep performing that way, " \
      "and we set what we charge for the upcoming period from that window. " \
      "Far more often than not, what ends up happening is value delivered increases, " \
      "but you are always paying for when the value delivered wasn't as high. " \
      "So long as OG is helping foster Transparency, Clarity, and Fairness that leads to Growth... " \
      "we will be making the impact we want to make... and that is most important."
  end

  # Framing C: priced-from lookback, this-period delivery, you pay, savings vs delivery.
  def billing_analysis_lookback_value(period)
    period.value_delivered_total.to_f
  end

  def billing_analysis_this_period_value(period)
    analysis = period.value_analysis
    return nil if analysis.blank?

    column = analysis.column_for(:current)
    total = analysis.totals[:current]
    return nil if column.blank? || total.blank?

    if column.in_progress?
      billing_extrapolate_money(total.value_sum, column.period_progress)
    else
      total.value_sum.to_f
    end
  end

  def billing_analysis_this_period_value_likely?(period)
    column = period.value_analysis&.column_for(:current)
    return true if period.incomplete?
    return false if column.blank?

    column.in_progress? || column.upcoming?
  end

  def billing_analysis_savings_vs_delivery(period)
    this_period_value = billing_analysis_this_period_value(period)
    return nil if this_period_value.nil?

    [this_period_value - period.amount_due.to_f, 0.0].max.round(2)
  end

  def billing_analysis_show_next_period?(period)
    column = period.value_analysis&.column_for(:current)
    return false if column.blank?

    !column.complete?
  end

  def billing_this_period_value_so_far(period)
    period.value_analysis&.totals&.dig(:current)&.value_sum&.to_f
  end

  def billing_this_period_pepm_so_far(period)
    period.value_analysis&.totals&.dig(:current)&.pepm
  end

  def billing_this_period_value_math_popover(period)
    total = period.value_analysis&.totals&.dig(:current)
    column = period.value_analysis&.column_for(:current)
    return "Not enough this-period activity yet to compute PEPM." if total.blank? || column.blank?

    base = billing_value_page_pepm_popover(
      total: total.value_sum,
      week_count: total.week_count,
      teammate_count: total.teammate_count,
      per_employee_week: total.per_employee_week,
      pepm: total.pepm,
      so_far: column.in_progress? || column.upcoming?
    )
    extras = []
    if column.in_progress?
      extras << "This uses value delivered in the current billable period so far (not the ~90-day lookback that set PEPM)."
      extras << "Likely savings below pace-projects this so-far total to 100% of the period."
    elsif column.upcoming?
      extras << "This period has not started; the figure is a trend projection from lookback onto the billable window."
    else
      extras << "This is actual value delivered during the billable period."
    end
    ([base] + extras).join(" ")
  end
end


