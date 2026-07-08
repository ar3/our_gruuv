# frozen_string_literal: true

# Check-ins Health dashboard: manager filter (shared with goals health) and spotlight counts from cache.
class CheckInsHealthSpotlightService
  EMPTY_SPOTLIGHT_STATS = {
    total_employees: 0,
    healthy_count: 0,
    warning_count: 0,
    needs_attention_count: 0,
    ok_percentage: 0,
    total_action_slots: 0,
    healthy_action_slots: 0,
    warning_action_slots: 0,
    needs_attention_action_slots: 0,
    actions_to_full_maap: 0
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
           :normalize_manager_filter, to: :filtering

  def paginated_index_data(manager_id, page:, items: 25)
    scope = filtered_teammates(manager_id)
    total_count = scope.count
    page = [page.to_i, 1].max
    teammates = scope.offset((page - 1) * items).limit(items).to_a

    {
      rows: rows_for_teammates(teammates),
      spotlight_stats: spotlight_stats_for(manager_id),
      total_count: total_count
    }
  end

  def rows_and_spotlight_for(manager_id)
    teammates = filtered_teammates(manager_id).to_a
    {
      rows: rows_for_teammates(teammates),
      spotlight_stats: spotlight_stats_for(manager_id)
    }
  end

  def spotlight_stats_for(manager_id)
    teammate_ids = filtered_teammate_ids(manager_id)
    stats = spotlight_stats_from_teammate_ids(teammate_ids)
    stats.merge(action_spotlight_stats_for(teammate_ids))
  end

  def action_spotlight_stats_for(teammate_ids)
    EngagementHealth::ClarityActionMetrics
      .spotlight_stats(organization: organization, teammate_ids: teammate_ids)
      .to_h
  end

  # Stats for the full Check-ins Health page from Required Clarity Gruuv Health rollups.
  def spotlight_stats_from_rows(employee_health_data)
    spotlight_stats_from_teammate_ids(
      Array(employee_health_data).map { |data| data.fetch(:teammate).id }
    )
  end

  # Backward-compatible entry point for specs and callers that only pass cache rows.
  def spotlight_stats_from_cache(employee_health_data)
    normalized = Array(employee_health_data).map do |data|
      records = data.fetch(:engagement_health_records, [])
      status = CheckInsHealthEngagementHealthSupport.clarity_rollup_status(records)
      { teammate_id: data.fetch(:teammate).id, status: status }
    end
    spotlight_stats_from_status_rows(normalized)
  end

  # Three-tier counts aligned with Goals/Observations Health Start Here widgets.
  def compact_spotlight_stats(manager_id)
    full = spotlight_stats_for(manager_id)
    {
      total_employees: full[:total_employees],
      healthy_count: full[:healthy_count],
      ok_count: full[:warning_count],
      concerning_count: full[:needs_attention_count]
    }
  end

  private

  def rows_for_teammates(teammates)
    return [] if teammates.empty?

    company = organization.root_company || organization
    teammate_ids = teammates.map(&:id)
    engagement_health_by_teammate_id = CheckInsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammate_ids
    )
    teammates.map do |teammate|
      {
        teammate: teammate,
        person: teammate.person,
        manager_teammate: Goals::HealthManagerPerson.manager_teammate_for(teammate, company: company),
        engagement_health_records: engagement_health_by_teammate_id[teammate.id] || [],
        action_breakdown: EngagementHealth::ClarityActionMetrics.for_records(
          engagement_health_by_teammate_id[teammate.id] || []
        )
      }
    end
  end

  def spotlight_stats_from_teammate_ids(teammate_ids)
    return EMPTY_SPOTLIGHT_STATS.dup if teammate_ids.blank?

    rollups_by_teammate_id = EngagementHealthStatus
      .where(
        organization: organization,
        teammate_id: teammate_ids,
        category: CheckInsHealthEngagementHealthSupport::CATEGORY,
        level: "category"
      )
      .index_by(&:teammate_id)

    status_rows = teammate_ids.map do |teammate_id|
      { teammate_id: teammate_id, status: rollups_by_teammate_id[teammate_id]&.status }
    end
    spotlight_stats_from_status_rows(status_rows)
  end

  def spotlight_stats_from_status_rows(status_rows)
    total_employees = status_rows.count
    healthy_count = 0
    warning_count = 0
    needs_attention_count = 0

    status_rows.each do |row|
      case row[:status]
      when EngagementHealth::HEALTHY
        healthy_count += 1
      when EngagementHealth::WARNING
        warning_count += 1
      when EngagementHealth::NEEDS_ATTENTION
        needs_attention_count += 1
      else
        needs_attention_count += 1
      end
    end

    ok_percentage = if total_employees.positive?
                        ((healthy_count + warning_count).to_f / total_employees * 100).round(1)
                      else
                        0
                      end

    {
      total_employees: total_employees,
      healthy_count: healthy_count,
      warning_count: warning_count,
      needs_attention_count: needs_attention_count,
      ok_percentage: ok_percentage
    }
  end
end
