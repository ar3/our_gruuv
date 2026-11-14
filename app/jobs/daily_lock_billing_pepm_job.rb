# frozen_string_literal: true

class DailyLockBillingPepmJob < ApplicationJob
  queue_as :default

  def perform(as_of: Date.current)
    as_of = as_of.to_date

    OrganizationBillingSetting.find_each do |setting|
      due_on = setting.next_payment_due_on
      due_on = Organizations::Billing::NextDueDate.call(cadence: setting.cadence, from: as_of) if due_on.blank? || due_on < as_of
      next unless due_on - 1.week == as_of

      Billing::LockDuePepmJob.perform_later(setting.organization_id, as_of: as_of)
    end
  end
end
