# frozen_string_literal: true

module EngagementHealth
  # Whether every active teammate has all five category rollups for a completed week.
  module WeeklyRollupCompleteness
    module_function

    def complete?(organization:, week_ending_on:, teammate_ids: nil)
      expected_ids = WeeklyRollupTeammateScope.active_teammate_ids(
        organization: organization,
        week_ending_on: week_ending_on,
        teammate_ids: teammate_ids
      )
      return true if expected_ids.empty?

      expected_count = expected_ids.size * EngagementHealth::CATEGORIES.size
      actual_count = EngagementHealthWeeklyRollup
        .where(organization: organization, week_ending_on: week_ending_on, teammate_id: expected_ids)
        .count

      actual_count >= expected_count
    end
  end
end
