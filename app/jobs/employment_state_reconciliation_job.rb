class EmploymentStateReconciliationJob < ApplicationJob
  queue_as :default

  def perform
    result = EmploymentStateReconciliationService.call
    return false unless result.ok?

    summary = result.value
    if summary[:corrected_teammates].positive?
      Sentry.capture_message(
        'Employment state reconciliation corrected teammate records',
        level: :warning,
        extra: summary.slice(:scanned_teammates, :corrected_teammates, :corrected_fields, :corrections)
      )
    end

    Rails.logger.info("EmploymentStateReconciliationJob summary: #{summary.inspect}")
    true
  end

  def self.perform_and_get_result
    new.perform
  end
end
