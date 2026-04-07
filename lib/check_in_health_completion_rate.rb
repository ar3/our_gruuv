# frozen_string_literal: true

# Shared logic for check-in health completion rate and category aggregation.
# Used by CheckInsHealthController (by_manager) and InsightsController (department leaderboard).
module CheckInHealthCompletionRate
  BAR_CATEGORIES = %w[red orange light_blue light_purple light_green green neon_green].freeze

  module_function

  # Earned points and max points for one cache (check-in health only; excludes milestones).
  def contribution_tuple_for_cache(cache)
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
    [pos_pts + assign_pts + aspir_pts, total_max]
  end

  # Completion rate from check-ins only (position, assignments, aspirations). Excludes milestones.
  # Point scores in the cache use CheckInHealthCacheBuilder’s blurred-window (CLARITY_BLURRED_DAYS) cutoff.
  def completion_rate_for_caches(caches)
    total_points = 0.0
    max_points = 0.0
    caches.each do |cache|
      pts, mx = contribution_tuple_for_cache(cache)
      total_points += pts
      max_points += mx
    end
    max_points.positive? ? (total_points / max_points * 100).round(1) : 0
  end

  # Same formula as CheckInHealthHelper#check_in_health_completion_rate_and_breakdown (single cache).
  # Returns nil if cache is nil; otherwise
  # { completion_rate:, position_pct:, assignments_pct:, aspirations_pct: }.
  def completion_breakdown_for_cache(cache)
    return nil unless cache

    pts = cache.completion_points
    pos_pts = pts[:position].to_f
    assign_pts = pts[:assignments].to_f
    aspir_pts = pts[:aspirations].to_f
    pos_max = 4.0
    assign_max = (cache.payload_assignments.size * 4).to_f
    assign_max = 4.0 if cache.payload_assignments.empty?
    aspir_max = (cache.payload_aspirations.size * 4).to_f
    aspir_max = 4.0 if cache.payload_aspirations.empty?
    total_pts = pos_pts + assign_pts + aspir_pts
    total_max = pos_max + assign_max + aspir_max
    rate = total_max.positive? ? (total_pts / total_max * 100).round(1) : 0
    {
      completion_rate: rate,
      position_pct: pos_max.positive? ? (pos_pts / pos_max * 100).round(0) : 0,
      assignments_pct: assign_max.positive? ? (assign_pts / assign_max * 100).round(0) : 0,
      aspirations_pct: aspir_max.positive? ? (aspir_pts / aspir_max * 100).round(0) : 0
    }
  end

  # Average of each direct report's own completion % (0 if they have no cache row). Uses per-person max denominators.
  def average_completion_rate_per_teammate(teammate_ids, organization_id)
    return 0.0 if teammate_ids.blank?

    caches_by_id = CheckInHealthCache.where(
      teammate_id: teammate_ids,
      organization_id: organization_id
    ).index_by(&:teammate_id)

    sum = 0.0
    teammate_ids.each do |tid|
      cache = caches_by_id[tid]
      if cache
        pts, mx = contribution_tuple_for_cache(cache)
        sum += mx.positive? ? (pts / mx * 100) : 0.0
      end
    end
    (sum / teammate_ids.size).round(1)
  end

  def teammate_fully_clear_on_check_ins?(cache)
    return false unless cache

    pts, mx = contribution_tuple_for_cache(cache)
    mx.positive? && pts >= mx
  end

  def aggregate_category_counts(items)
    return BAR_CATEGORIES.index_with { 0 } if items.empty?
    counts = items.group_by { |i| i['category'].to_s }.transform_values(&:count)
    BAR_CATEGORIES.index_with { |c| counts[c].to_i }
  end

  def aggregate_position_counts(positions)
    return BAR_CATEGORIES.index_with { 0 } if positions.empty?
    counts = positions.group_by { |p| p['category'].to_s.presence || 'red' }.transform_values(&:count)
    BAR_CATEGORIES.index_with { |c| counts[c].to_i }
  end
end
