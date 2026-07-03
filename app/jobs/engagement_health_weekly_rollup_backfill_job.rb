# frozen_string_literal: true

class EngagementHealthWeeklyRollupBackfillJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(organization_id, *) { "engagement_health_weekly_backfill_#{organization_id}" }

  def perform(organization_id, week_ending_on_values)
    organization = Organization.find_by(id: organization_id)
    return unless organization

    Array(week_ending_on_values).map(&:to_date).uniq.each do |week_ending_on|
      next if week_ending_on >= Date.current
      next if EngagementHealth::WeeklyRollupCompleteness.complete?(organization: organization, week_ending_on: week_ending_on)

      EngagementHealth::WeeklyRollupSnapshotter.call(organization: organization, week_ending_on: week_ending_on)
    end
  end
end
