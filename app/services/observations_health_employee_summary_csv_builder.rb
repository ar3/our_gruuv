# frozen_string_literal: true

require "csv"

# One row per employee on the Observations Health dashboard (cache payload + manager).
class ObservationsHealthEmployeeSummaryCsvBuilder
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
      "Overall Status",
      "Given Status",
      "Given OGO Count",
      "Given Last Published At",
      "Received Status",
      "Received OGO Count",
      "Received Last Published At",
      "Kudos Mix Band",
      "Kudos Count",
      "Constructive Count",
      "Kudos Mix Display Ratio",
      "Rating Intensity Band",
      "Less Extreme Rating Count",
      "Most Extreme Rating Count",
      "Rating Intensity Display Ratio",
      "Cache Refreshed At"
    ]
  end

  def build_row(row)
    teammate = row[:teammate]
    person = row[:person]
    manager = row[:manager]
    given = stringify_keys(row[:given])
    received = stringify_keys(row[:received])
    kudos = stringify_keys(row[:kudos_mix])
    intensity = stringify_keys(row[:rating_intensity])

    [
      person&.display_name.to_s,
      person&.email.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      row[:overall_status].to_s,
      given["status"].to_s,
      given["observations_count"].to_s,
      iso_or_blank(given["last_published_at"]),
      received["status"].to_s,
      received["observations_count"].to_s,
      iso_or_blank(received["last_published_at"]),
      kudos["band"].to_s,
      kudos["kudos_count"].to_s,
      kudos["constructive_count"].to_s,
      kudos["display_ratio"].to_s,
      intensity["band"].to_s,
      intensity["less_extreme_count"].to_s,
      intensity["most_extreme_count"].to_s,
      intensity["display_ratio"].to_s,
      datetime(row[:refreshed_at])
    ]
  end

  def stringify_keys(hash)
    return {} if hash.blank?

    hash.stringify_keys
  end

  def iso_or_blank(value)
    return "" if value.blank?

    Time.zone.parse(value.to_s)&.iso8601 || value.to_s
  rescue ArgumentError
    value.to_s
  end

  def datetime(value)
    return "" if value.blank?

    value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d %H:%M") : value.to_s
  end
end
