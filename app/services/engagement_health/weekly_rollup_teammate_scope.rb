# frozen_string_literal: true

module EngagementHealth
  # Teammates employed at any point during the scorecard week (Mon–Sun).
  # Shared by weekly rollup snapshotter, completeness checks, and scorecard readers.
  module WeeklyRollupTeammateScope
    module_function

    def active_teammate_ids(organization:, week_ending_on:, teammate_ids: nil)
      week_ending_on = week_ending_on.to_date
      week_start_time = (week_ending_on - 6.days).in_time_zone.beginning_of_day
      week_end_time = week_ending_on.in_time_zone.end_of_day

      scope = CompanyTeammate
        .for_organization_hierarchy(organization)
        .where.not(first_employed_at: nil)
      scope = scope.where(id: teammate_ids) if teammate_ids

      scope.pluck(:id, :first_employed_at, :last_terminated_at).filter_map do |id, first_employed_at, last_terminated_at|
        id if employed_during_week?(first_employed_at, last_terminated_at, week_start_time, week_end_time)
      end
    end

    def employed_during_week?(first_employed_at, last_terminated_at, week_start_time, week_end_time)
      return false if first_employed_at.blank?

      hired_at = first_employed_at.to_time.in_time_zone
      terminated_at = last_terminated_at&.to_time&.in_time_zone

      hired_at <= week_end_time && (terminated_at.nil? || terminated_at >= week_start_time)
    end
  end
end
