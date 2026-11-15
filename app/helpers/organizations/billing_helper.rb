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
end
