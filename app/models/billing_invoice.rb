# frozen_string_literal: true

class BillingInvoice < ApplicationRecord
  STATUSES = %w[open paid].freeze

  belongs_to :organization

  validates :status, inclusion: { in: STATUSES }
  validates :cadence, inclusion: { in: OrganizationBillingSetting::CADENCES }
  validates :period_starts_on, :period_ends_on, :due_on, :pepm, :amount_due, presence: true
  validates :teammate_count, numericality: { greater_than_or_equal_to: 0 }

  scope :open_invoices, -> { where(status: "open").order(due_on: :asc) }
  scope :paid_invoices, -> { where(status: "paid").order(paid_at: :desc) }

  def open?
    status == "open"
  end

  def paid?
    status == "paid"
  end
end
