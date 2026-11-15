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
end

