# frozen_string_literal: true

# Observations Health dashboard: manager filter (shared with goals health) and rows from cache.
class ObservationsHealthSpotlightService
  EMPTY_PAYLOAD = {
    "given" => { "status" => "red", "last_published_at" => nil, "observations_count" => 0 },
    "received" => { "status" => "red", "last_published_at" => nil, "observations_count" => 0 },
    "kudos_mix" => {
      "band" => "no_data",
      "kudos_count" => 0,
      "constructive_count" => 0,
      "display_ratio" => "0:0"
    },
    "rating_intensity" => {
      "band" => "no_data",
      "less_extreme_count" => 0,
      "most_extreme_count" => 0,
      "display_ratio" => "0:0"
    },
    "overall_status" => "red"
  }.freeze

  attr_reader :organization, :filtering

  def initialize(organization:, current_person:, current_company_teammate:, manage_employment:)
    @organization = organization
    @filtering = GoalsHealthSpotlightService.new(
      organization: organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: manage_employment
    )
  end

  delegate :filtered_teammates, :available_manager_filter_options, :default_manager_filter_value,
           :normalize_manager_filter, to: :filtering

  def rows_and_spotlight_for(manager_id)
    teammates = filtered_teammates(manager_id).to_a
    caches_by_teammate_id = ObservationHealthCache
      .where(organization: organization, teammate_id: teammates.map(&:id))
      .index_by(&:teammate_id)
    rows = teammates.map { |teammate| row_for(teammate, caches_by_teammate_id[teammate.id]) }
    { rows: rows, spotlight_stats: spotlight_stats(rows) }
  end

  private

  def row_for(teammate, cache)
    payload = cache&.payload || EMPTY_PAYLOAD
    overall = payload["overall_status"].to_s

    {
      teammate: teammate,
      person: teammate.person,
      manager: Goals::HealthManagerPerson.for(teammate),
      manager_teammate: Goals::HealthManagerPerson.manager_teammate_for(teammate),
      cache: cache,
      refreshed_at: cache&.refreshed_at,
      given: payload["given"] || EMPTY_PAYLOAD["given"],
      received: payload["received"] || EMPTY_PAYLOAD["received"],
      kudos_mix: payload["kudos_mix"] || EMPTY_PAYLOAD["kudos_mix"],
      rating_intensity: payload["rating_intensity"] || EMPTY_PAYLOAD["rating_intensity"],
      overall_status: overall,
      status: spotlight_status(overall)
    }
  end

  def spotlight_status(overall_status)
    case overall_status.to_s
    when "green"
      :healthy
    when "yellow"
      :ok
    else
      :concerning
    end
  end

  def spotlight_stats(rows)
    total_employees = rows.count
    healthy_count = rows.count { |row| row[:status] == :healthy }
    ok_count = rows.count { |row| row[:status] == :ok }
    concerning_count = rows.count { |row| row[:status] == :concerning }
    concerning_pct = total_employees.positive? ? ((concerning_count.to_f / total_employees) * 100).round(1) : 0.0

    {
      total_employees: total_employees,
      healthy_count: healthy_count,
      ok_count: ok_count,
      concerning_count: concerning_count,
      concerning_pct: concerning_pct
    }
  end
end
