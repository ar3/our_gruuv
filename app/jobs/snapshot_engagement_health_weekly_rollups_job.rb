# frozen_string_literal: true

# Snapshots the most recently completed Sunday for every organization hierarchy
# that has employed teammates. Runs after the daily live-cache refresh.
class SnapshotEngagementHealthWeeklyRollupsJob < ApplicationJob
  queue_as :default

  def perform
    week_ending_on = Date.current.beginning_of_week(:monday) - 1.day
    return if week_ending_on >= Date.current

    organization_ids = CompanyTeammate.employed.distinct.pluck(:organization_id)
    Organization.where(id: organization_ids).find_each do |organization|
      next if EngagementHealth::WeeklyRollupCompleteness.complete?(organization: organization, week_ending_on: week_ending_on)

      EngagementHealth::WeeklyRollupSnapshotter.call(organization: organization, week_ending_on: week_ending_on)
    end
  end
end
