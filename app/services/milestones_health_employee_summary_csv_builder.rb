# frozen_string_literal: true

require "csv"

class MilestonesHealthEmployeeSummaryCsvBuilder
  def initialize(rows)
    @rows = rows
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      rows.each { |row| csv << build_row(row) }
    end
  end

  private

  attr_reader :rows

  def headers
    [
      "Employee Name",
      "Employee Email",
      "Manager Name",
      "Manager Email",
      "Milestones Status",
      "Healthy Abilities",
      "Warning Abilities",
      "Needs Attention Abilities",
      "Empty Reason",
      "Gruuv Health Computed At"
    ]
  end

  def build_row(row)
    person = row[:person]
    manager = row[:manager]
    counts = row[:status_counts] || {}
    [
      person&.display_name.to_s,
      person&.email.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      EngagementHealth::STATUS_LABELS.fetch(row[:eh_status].to_s) { row[:eh_status].to_s },
      counts[EngagementHealth::HEALTHY].to_i,
      counts[EngagementHealth::WARNING].to_i,
      counts[EngagementHealth::NEEDS_ATTENTION].to_i,
      row[:empty_reason].to_s,
      datetime(row[:refreshed_at])
    ]
  end

  def datetime(value)
    return "" if value.blank?

    value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d %H:%M") : value.to_s
  end
end
