# frozen_string_literal: true

# Check-ins Health dashboard: manager filter (shared with goals health) and spotlight counts from cache.
class CheckInsHealthSpotlightService
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
    teammate_ids = teammates.map(&:id)
    caches_by_teammate_id = CheckInHealthCache
      .where(organization: organization, teammate_id: teammate_ids)
      .index_by(&:teammate_id)
    engagement_health_by_teammate_id = CheckInsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammate_ids
    )
    employee_health_data = teammates.map do |teammate|
      {
        teammate: teammate,
        person: teammate.person,
        cache: caches_by_teammate_id[teammate.id],
        engagement_health_records: engagement_health_by_teammate_id[teammate.id] || []
      }
    end
    { rows: employee_health_data, spotlight_stats: spotlight_stats_from_rows(employee_health_data) }
  end

  def spotlight_stats_for(manager_id)
    rows_and_spotlight_for(manager_id).fetch(:spotlight_stats)
  end

  # Stats for the full Check-ins Health page from Required Clarity Gruuv Health rollups.
  def spotlight_stats_from_rows(employee_health_data)
    total_employees = employee_health_data.count
    healthy_count = 0
    at_risk_count = 0
    needs_attention_count = 0

    employee_health_data.each do |data|
      case CheckInsHealthEngagementHealthSupport.clarity_rollup_status(data[:engagement_health_records])
      when EngagementHealth::HEALTHY
        healthy_count += 1
      when EngagementHealth::AT_RISK
        at_risk_count += 1
      when EngagementHealth::NEEDS_ATTENTION
        needs_attention_count += 1
      else
        needs_attention_count += 1
      end
    end

    ok_percentage = if total_employees.positive?
                        ((healthy_count + at_risk_count).to_f / total_employees * 100).round(1)
                      else
                        0
                      end

    {
      total_employees: total_employees,
      healthy_count: healthy_count,
      at_risk_count: at_risk_count,
      needs_attention_count: needs_attention_count,
      ok_percentage: ok_percentage
    }
  end

  # Backward-compatible entry point for specs and callers that only pass cache rows.
  def spotlight_stats_from_cache(employee_health_data)
    normalized = Array(employee_health_data).map do |data|
      data.merge(engagement_health_records: data.fetch(:engagement_health_records, []))
    end
    spotlight_stats_from_rows(normalized)
  end

  # Three-tier counts aligned with Goals/Observations Health Start Here widgets.
  def compact_spotlight_stats(manager_id)
    full = spotlight_stats_for(manager_id)
    {
      total_employees: full[:total_employees],
      healthy_count: full[:healthy_count],
      ok_count: full[:at_risk_count],
      concerning_count: full[:needs_attention_count]
    }
  end
end
