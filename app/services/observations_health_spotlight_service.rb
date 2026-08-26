# frozen_string_literal: true

# Observations Health dashboard: Given/Received from Gruuv Health; kudos/rating from observation cache.
class ObservationsHealthSpotlightService
  EMPTY_MIX_PAYLOAD = {
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
    }
  }.freeze

  EMPTY_SPOTLIGHT_STATS = {
    total_employees: 0,
    healthy_count: 0,
    warning_count: 0,
    needs_attention_count: 0,
    ok_count: 0,
    concerning_count: 0,
    concerning_pct: 0.0
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

  delegate :filtered_teammates, :filtered_teammate_ids, :available_manager_filter_options, :default_manager_filter_value,
           :normalize_manager_filter, :manager_filter_viewable?, to: :filtering

  def rows_and_spotlight_for(manager_id)
    teammates = filtered_teammates(manager_id).to_a
    rows = rows_for_teammates(teammates)
    { rows: rows, spotlight_stats: spotlight_stats(rows) }
  end

  # Three-tier counts for Start Here compact widget (ok_count = Warning).
  def compact_spotlight_stats(manager_id)
    stats = rows_and_spotlight_for(manager_id)[:spotlight_stats]
    {
      total_employees: stats[:total_employees],
      healthy_count: stats[:healthy_count],
      ok_count: stats[:warning_count],
      concerning_count: stats[:needs_attention_count]
    }
  end

  private

  def rows_for_teammates(teammates)
    return [] if teammates.empty?

    teammate_ids = teammates.map(&:id)
    engagement_health_by_teammate_id = ObservationsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammate_ids
    )
    caches_by_teammate_id = ObservationHealthCache
      .where(organization: organization, teammate_id: teammate_ids)
      .index_by(&:teammate_id)
    band_counts_by_teammate_id = ogo_band_counts_by_teammate(teammates)

    teammates.map do |teammate|
      row_for(
        teammate,
        engagement_health_by_teammate_id[teammate.id] || [],
        caches_by_teammate_id[teammate.id],
        band_counts_by_teammate_id[teammate.id] || empty_band_counts
      )
    end
  end

  def row_for(teammate, records, cache, band_counts)
    payload = cache&.payload || {}
    given_count = payload.dig("given", "observations_count")
    received_count = payload.dig("received", "observations_count")
    given = ObservationsHealthEngagementHealthSupport.section_payload(
      records,
      category: EngagementHealth::CATEGORY_OGO_GIVEN,
      observations_count: given_count
    ).merge(band_counts[:given])
    received = ObservationsHealthEngagementHealthSupport.section_payload(
      records,
      category: EngagementHealth::CATEGORY_OGO_RECEIVED,
      observations_count: received_count
    ).merge(band_counts[:received])
    apply_band_total_as_observations_count!(given)
    apply_band_total_as_observations_count!(received)
    overall = ObservationsHealthEngagementHealthSupport.overall_status(records) ||
              EngagementHealth::NEEDS_ATTENTION
    eh_computed_at = ObservationsHealthEngagementHealthSupport.computed_at_for(records)

    {
      teammate: teammate,
      person: teammate.person,
      manager: Goals::HealthManagerPerson.for(teammate),
      manager_teammate: Goals::HealthManagerPerson.manager_teammate_for(teammate),
      cache: cache,
      refreshed_at: eh_computed_at || cache&.refreshed_at,
      engagement_health_records: records,
      given: given,
      received: received,
      kudos_mix: payload["kudos_mix"] || EMPTY_MIX_PAYLOAD["kudos_mix"],
      rating_intensity: payload["rating_intensity"] || EMPTY_MIX_PAYLOAD["rating_intensity"],
      overall_status: overall,
      status: spotlight_status(overall)
    }
  end

  def empty_band_counts
    empty = { "healthy_count" => 0, "warning_count" => 0, "needs_attention_count" => 0 }
    { given: empty.dup, received: empty.dup }
  end

  def apply_band_total_as_observations_count!(section)
    total = section["healthy_count"].to_i + section["warning_count"].to_i + section["needs_attention_count"].to_i
    section["observations_count"] = total if total.positive? || section["never"] == true
  end

  # Counts published OGOs by Gruuv Health age band (Healthy ≤30d, Warning 31–89d, Needs Attention ≥90d).
  # Uses the same scopes as EngagementHealth so captions cannot disagree with the cell status.
  def ogo_band_counts_by_teammate(teammates)
    reference_time = Time.current

    teammates.each_with_object({}) do |teammate, result|
      given = { "healthy_count" => 0, "warning_count" => 0, "needs_attention_count" => 0 }
      received = { "healthy_count" => 0, "warning_count" => 0, "needs_attention_count" => 0 }

      Observations::HealthScopes.given_scope(teammate, organization).pluck(:published_at).each do |published_at|
        increment_band_count!(given, published_at, reference_time: reference_time)
      end
      Observations::HealthScopes.received_scope(teammate, organization).distinct.pluck(:published_at).each do |published_at|
        increment_band_count!(received, published_at, reference_time: reference_time)
      end

      result[teammate.id] = { given: given, received: received }
    end
  end

  def increment_band_count!(counts, published_at, reference_time:)
    status = EngagementHealth::Thresholds.status_for_last_event(
      published_at,
      healthy_within: EngagementHealth::Thresholds::OGO_HEALTHY_WITHIN_DAYS,
      needs_attention_at: EngagementHealth::Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS,
      reference_time: reference_time
    )
    key = "#{status}_count"
    counts[key] = counts[key].to_i + 1 if counts.key?(key)
  end

  def spotlight_status(overall_status)
    case overall_status.to_s
    when EngagementHealth::HEALTHY
      :healthy
    when EngagementHealth::WARNING
      :ok
    else
      :concerning
    end
  end

  def spotlight_stats(rows)
    total_employees = rows.count
    healthy_count = rows.count { |row| row[:status] == :healthy }
    warning_count = rows.count { |row| row[:status] == :ok }
    needs_attention_count = rows.count { |row| row[:status] == :concerning }
    concerning_pct = total_employees.positive? ? ((needs_attention_count.to_f / total_employees) * 100).round(1) : 0.0

    {
      total_employees: total_employees,
      healthy_count: healthy_count,
      warning_count: warning_count,
      needs_attention_count: needs_attention_count,
      ok_count: warning_count,
      concerning_count: needs_attention_count,
      concerning_pct: concerning_pct
    }
  end
end
