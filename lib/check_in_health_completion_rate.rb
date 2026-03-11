# frozen_string_literal: true

# Shared logic for check-in health completion rate and category aggregation.
# Used by CheckInsHealthController (by_manager) and InsightsController (department leaderboard).
module CheckInHealthCompletionRate
  BAR_CATEGORIES = %w[red orange light_blue light_purple light_green green neon_green].freeze

  module_function

  # Completion rate from check-ins only (position, assignments, aspirations). Excludes milestones.
  def completion_rate_for_caches(caches)
    total_points = 0.0
    max_points = 0.0
    caches.each do |cache|
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
    end
    max_points.positive? ? (total_points / max_points * 100).round(1) : 0
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
