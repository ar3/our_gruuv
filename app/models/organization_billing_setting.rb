# frozen_string_literal: true

class OrganizationBillingSetting < ApplicationRecord
  CADENCES = %w[monthly quarterly semiannual].freeze
  DISCOUNTS = {
    "monthly" => 0.0,
    "quarterly" => 0.10,
    "semiannual" => 0.20
  }.freeze

  belongs_to :organization

  validates :cadence, inclusion: { in: CADENCES }

  def discount_rate
    DISCOUNTS.fetch(cadence)
  end

  def discount_percent
    (discount_rate * 100).to_i
  end

  CADENCE_LABELS = {
    "monthly" => "Monthly (full price)",
    "quarterly" => "Quarterly (10% discount)",
    "semiannual" => "Semi-annually (20% discount)"
  }.freeze

  def cadence_label
    CADENCE_LABELS.fetch(cadence, cadence.to_s.humanize)
  end

  def self.cadence_label_for(cadence)
    CADENCE_LABELS.fetch(cadence.to_s, cadence.to_s.humanize)
  end

  def self.for_organization!(organization)
    find_or_create_by!(organization: organization) do |setting|
      setting.cadence = "monthly"
    end
  end
end
