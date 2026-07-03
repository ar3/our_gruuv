# frozen_string_literal: true

module Insights
  module OgScorecard
    # Weekly counts for ability milestones earned (this week, rolling 90 days, and all-time through each Sunday).
    class MilestonesWeekCounts
      def self.call(company:, week_starts:, teammate_ids: nil)
        new(company: company, week_starts: week_starts, teammate_ids: teammate_ids).call
      end

      def initialize(company:, week_starts:, teammate_ids: nil)
        @company = company
        @week_starts = week_starts
        @teammate_ids = teammate_ids
      end

      def call
        {
          milestones_earned_this_week: counts_by_week(:total_this_week),
          milestones_earned_90_days: counts_by_week(:total_90_days),
          milestones_earned_all_time: counts_by_week(:total_all_time),
          unique_teammates_milestone_this_week: counts_by_week(:unique_this_week),
          unique_teammates_milestone_90_days: counts_by_week(:unique_90_days),
          unique_teammates_milestone_all_time: counts_by_week(:unique_all_time)
        }
      end

      private

      attr_reader :company, :week_starts, :teammate_ids

      def teammate_in_scope?(teammate_id)
        teammate_id.present? && (teammate_ids.nil? || teammate_ids.include?(teammate_id))
      end

      def counts_by_week(mode)
        week_starts.index_with do |week_start|
          week_end_date = week_start + 6.days
          rows = rows_for_mode(week_start, week_end_date, mode)
          case mode
          when :unique_this_week, :unique_90_days, :unique_all_time
            rows.map(&:first).uniq.size
          when :total_this_week, :total_90_days, :total_all_time
            rows.size
          else
            0
          end
        end
      end

      def rows_for_mode(week_start, week_end_date, mode)
        case mode
        when :unique_this_week, :total_this_week
          milestone_rows.select { |_tid, attained_at| attained_in_week?(attained_at, week_start, week_end_date) }
        when :unique_90_days, :total_90_days
          window_start = week_end_date - 89.days
          milestone_rows.select { |_tid, attained_at| attained_in_range?(attained_at, window_start, week_end_date) }
        when :unique_all_time
          active_ids = active_teammate_ids_for_week(week_end_date).to_set
          milestone_rows.select do |teammate_id, attained_at|
            active_ids.include?(teammate_id) && attained_on_or_before?(attained_at, week_end_date)
          end
        when :total_all_time
          milestone_rows.select { |_tid, attained_at| attained_on_or_before?(attained_at, week_end_date) }
        else
          []
        end
      end

      def attained_on_or_before?(attained_at, week_end_date)
        return false if attained_at.blank?

        attained_at.to_time.in_time_zone <= week_end_date.in_time_zone.end_of_day
      end

      def active_teammate_ids_for_week(week_ending_on)
        EngagementHealth::WeeklyRollupTeammateScope.active_teammate_ids(
          organization: company,
          week_ending_on: week_ending_on,
          teammate_ids: teammate_ids
        )
      end

      def attained_in_week?(attained_at, week_start, week_end_date)
        attained_in_range?(attained_at, week_start, week_end_date)
      end

      def attained_in_range?(attained_at, start_date, end_date)
        return false if attained_at.blank?

        date = attained_at.to_date
        date >= start_date && date <= end_date
      end

      def milestone_rows
        @milestone_rows ||= begin
          teammate_scope = CompanyTeammate.for_organization_hierarchy(company).select(:id)
          teammate_scope = teammate_scope.where(id: teammate_ids) if teammate_ids
          TeammateMilestone
            .joins(:ability)
            .where(abilities: { company_id: company.id })
            .where(teammate_id: teammate_scope)
            .pluck(:teammate_id, :attained_at)
            .select { |teammate_id, _attained_at| teammate_in_scope?(teammate_id) }
        end
      end
    end
  end
end
