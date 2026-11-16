# frozen_string_literal: true

class BillingInvoice < ApplicationRecord
  # Manual (impersonation dropdown): open, waived.
  # Automation / processor only: processing, paid, failed, refunded.
  MANUAL_STATUSES = %w[open waived].freeze
  AUTOMATION_STATUSES = %w[processing paid failed refunded].freeze
  STATUSES = (MANUAL_STATUSES + AUTOMATION_STATUSES).freeze

  STATUS_LABELS = {
    "open" => "Open",
    "waived" => "Waived",
    "processing" => "Processing",
    "paid" => "Paid",
    "failed" => "Failed",
    "refunded" => "Refunded"
  }.freeze

  belongs_to :organization

  validates :status, inclusion: { in: STATUSES }
  validates :cadence, inclusion: { in: OrganizationBillingSetting::CADENCES }
  validates :period_starts_on, :period_ends_on, :due_on, :pepm, :amount_due, presence: true
  validates :teammate_count, numericality: { greater_than_or_equal_to: 0 }

  scope :open_invoices, -> { where(status: "open").order(due_on: :asc) }
  scope :paid_invoices, -> { where(status: "paid").order(paid_at: :desc) }
  scope :waived_invoices, -> { where(status: "waived").order(due_on: :desc) }
  scope :closed_invoices, -> {
    where(status: %w[paid waived refunded]).order(Arel.sql("COALESCE(paid_at, updated_at) DESC"))
  }

  def open?
    status == "open"
  end

  def waived?
    status == "waived"
  end

  def paid?
    status == "paid"
  end

  def processing?
    status == "processing"
  end

  def failed?
    status == "failed"
  end

  def refunded?
    status == "refunded"
  end

  def payable?
    open? || failed?
  end

  def closed?
    paid? || waived? || refunded?
  end

  def status_label
    STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def self.manual_status_options
    MANUAL_STATUSES.map { |status| [STATUS_LABELS.fetch(status), status] }
  end

  def apply_manual_status!(new_status)
    raise ArgumentError, "not a manual status" unless MANUAL_STATUSES.include?(new_status.to_s)

    attrs = { status: new_status.to_s }
    attrs[:paid_at] = nil if new_status.to_s != "paid"
    update!(attrs)
  end

  # Lookback window used when PEPM was locked (calculation day = due − 1 week).
  def value_lookback_ends_on
    due_on - 1.week
  end

  def value_lookback_starts_on
    value_lookback_ends_on - 90.days
  end

  # Undiscounted value-based monthly amount; falls back to charged PEPM for older rows.
  def og_cost_pepm
    (value_based_pepm.presence || pepm).to_f
  end

  def free_until_value_floor?
    og_cost_pepm.zero? || pepm.to_f.zero?
  end
end
