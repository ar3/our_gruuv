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

  def billing_in_progress_activity_popover(key:, cell:, company_name:, period_progress:)
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

  def billing_upcoming_activity_popover(key:, cell:, company_name:, starts_on:, ends_on:)
    outcome = billing_value_outcome_popover(
      key: key,
      teammate_count: cell.teammate_count,
      activity_count: cell.activity_count,
      value_sum: cell.value_sum,
      company_name: company_name
    )
    "This is an estimated projection of the value #{company_name} will receive during the next period between #{l(starts_on, format: :long)} and #{l(ends_on, format: :long)}. #{outcome}"
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
end


