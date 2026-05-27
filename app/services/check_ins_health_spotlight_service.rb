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
    caches_by_teammate_id = CheckInHealthCache
      .where(organization: organization, teammate_id: teammates.map(&:id))
      .index_by(&:teammate_id)
    employee_health_data = teammates.map do |teammate|
      { teammate: teammate, person: teammate.person, cache: caches_by_teammate_id[teammate.id] }
    end
    { rows: employee_health_data, spotlight_stats: spotlight_stats_from_cache(employee_health_data) }
  end

  def spotlight_stats_for(manager_id)
    rows_and_spotlight_for(manager_id).fetch(:spotlight_stats)
  end

  # Stats for the full Check-ins Health page (includes completion rate).
  def spotlight_stats_from_cache(employee_health_data)
    total_employees = employee_health_data.count
    all_healthy = 0
    needing_attention = 0
    total_points = 0.0
    max_points = 0.0

    employee_health_data.each do |data|
      cache = data[:cache]
      unless cache
        needing_attention += 1
        next
      end
      points = cache.completion_points
      pos_pts = points[:position].to_f
      assign_pts = points[:assignments].to_f
      aspir_pts = points[:aspirations].to_f
      pos_max = 4.0
      assign_max = (cache.payload_assignments.size * 4).to_f
      assign_max = 4.0 if cache.payload_assignments.empty?
      aspir_max = (cache.payload_aspirations.size * 4).to_f
      aspir_max = 4.0 if cache.payload_aspirations.empty?
      total_max = pos_max + assign_max + aspir_max
      total_points += pos_pts + assign_pts + aspir_pts
      max_points += total_max
      if pos_pts >= 4 && assign_pts >= assign_max && aspir_pts >= aspir_max
        all_healthy += 1
      elsif pos_pts < 2 || assign_pts < assign_max * 0.5 || aspir_pts < aspir_max * 0.5
        needing_attention += 1
      end
    end

    completion_rate = max_points.positive? ? (total_points / max_points * 100).round(1) : 0

    {
      total_employees: total_employees,
      all_healthy: all_healthy,
      needing_attention: needing_attention,
      completion_rate: completion_rate
    }
  end

  # Three-tier counts aligned with Goals/Observations Health Start Here widgets.
  def compact_spotlight_stats(manager_id)
    full = spotlight_stats_for(manager_id)
    total = full[:total_employees]
    healthy = full[:all_healthy]
    concerning = full[:needing_attention]
    {
      total_employees: total,
      healthy_count: healthy,
      ok_count: [ total - healthy - concerning, 0 ].max,
      concerning_count: concerning
    }
  end
end
