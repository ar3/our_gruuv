# frozen_string_literal: true

# Milestones Health dashboard: category rollups + ability items from EngagementHealth.
# Manager filtering is shared with Goals/Check-ins/Observations via GoalsHealthSpotlightService.
class MilestonesHealthSpotlightService
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

  def rows_and_spotlight_for(manager_id)
    teammates = filtered_teammates(manager_id).to_a
    rows = rows_for_teammates(teammates)
    { rows: rows, spotlight_stats: spotlight_stats(rows) }
  end

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

    records_by_teammate_id = MilestonesHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammates.map(&:id)
    )

    teammates.map { |teammate| row_for(teammate, records_by_teammate_id[teammate.id] || []) }
  end

  def row_for(teammate, records)
    category = MilestonesHealthEngagementHealthSupport.category_rollup(records)
    eh_status = MilestonesHealthEngagementHealthSupport.category_status(records)
    items = MilestonesHealthEngagementHealthSupport.items_for(records)

    {
      teammate: teammate,
      person: teammate.person,
      manager: Goals::HealthManagerPerson.for(teammate),
      manager_teammate: Goals::HealthManagerPerson.manager_teammate_for(teammate),
      status: MilestonesHealthEngagementHealthSupport.spotlight_symbol(eh_status),
      eh_status: eh_status,
      engagement_health_records: records,
      empty_reason: category&.inputs&.dig("empty_reason"),
      status_counts: MilestonesHealthEngagementHealthSupport.status_counts(items),
      attention_items: attention_items(items),
      refreshed_at: MilestonesHealthEngagementHealthSupport.computed_at_for(records)
    }
  end

  def attention_items(items)
    Array(items)
      .select { |item| item.status != EngagementHealth::HEALTHY }
      .sort_by { |item| [EngagementHealth.status_severity_rank(item.status), item.inputs["name"].to_s.downcase] }
      .first(5)
      .map do |item|
        {
          name: item.inputs["name"].presence || "Ability ##{item.entity_id}",
          entity_id: item.entity_id,
          status: item.status,
          reason: MilestonesHealthEngagementHealthSupport.reason_copy(item.inputs["reason"]),
          required_level: item.inputs["required_level"],
          earned_level: item.inputs["earned_level"]
        }
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
