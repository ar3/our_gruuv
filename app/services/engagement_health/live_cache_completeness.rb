# frozen_string_literal: true

module EngagementHealth
  # Whether every in-scope employed teammate has all five live category rollups.
  module LiveCacheCompleteness
    module_function

    def complete?(organization:, teammate_ids:)
      return true if teammate_ids.blank?

      expected_count = teammate_ids.size * EngagementHealth::CATEGORIES.size
      actual_count = EngagementHealthStatus
        .category_rollups
        .where(organization: organization, teammate_id: teammate_ids)
        .count

      actual_count >= expected_count
    end

    def missing_teammate_ids(organization:, teammate_ids:)
      return [] if teammate_ids.blank?

      cached_by_teammate = EngagementHealthStatus
        .category_rollups
        .where(organization: organization, teammate_id: teammate_ids)
        .group(:teammate_id)
        .count

      teammate_ids.reject do |teammate_id|
        cached_by_teammate.fetch(teammate_id, 0) >= EngagementHealth::CATEGORIES.size
      end
    end
  end
end
