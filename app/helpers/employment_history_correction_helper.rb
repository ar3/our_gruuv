# frozen_string_literal: true

module EmploymentHistoryCorrectionHelper
  def employment_history_duration_label(seconds)
    return '—' if seconds.blank? || seconds <= 0

    days = (seconds / 1.day).floor
    if days >= 365
      years = (days / 365.0)
      "#{number_with_precision(years, precision: 1)} years"
    elsif days >= 30
      months = (days / 30.0)
      "#{number_with_precision(months, precision: 1)} months"
    else
      "#{days} days"
    end
  end
end
