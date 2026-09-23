# frozen_string_literal: true

module ExpectationsComplianceHelper
  include EmploymentHistoryCorrectionHelper

  def expectations_compliance_status_label(row)
    if row.compliant
      "Signed"
    elsif row.due_by.present? && row.due_by < Time.current
      "Overdue"
    elsif row.latest_signature_at.blank?
      "Needs signature"
    else
      "Needs re-sign"
    end
  end

  def expectations_compliance_status_badge_class(row)
    if row.compliant
      "text-bg-success"
    elsif row.due_by.present? && row.due_by < Time.current
      "text-bg-danger"
    else
      "text-bg-warning"
    end
  end
end
