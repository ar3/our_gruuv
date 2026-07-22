# frozen_string_literal: true

module Insights
  module OgScorecard
    # Weekly goal metrics: active owners, goal check-ins, and recent completions.
    class GoalsWeekCounts
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
          unique_teammates_active_goal: counts_by_week(:active_goal),
          unique_teammates_active_goal_90_days: counts_by_week(:active_goal_90_days),
          unique_teammates_goal_check_in_this_week: counts_by_week(:goal_check_in),
          unique_teammates_completed_goal_90_days: counts_by_week(:completed_90_days)
        }
      end

      private

      attr_reader :company, :week_starts, :teammate_ids

      def teammate_in_scope?(owner_id)
        owner_id.present? && (teammate_ids.nil? || teammate_ids.include?(owner_id))
      end

      def counts_by_week(mode)
        week_starts.index_with do |week_start|
          week_end_date = week_start + 6.days
          reference_time = week_end_date.in_time_zone.end_of_day
          case mode
          when :active_goal
            active_owner_ids(reference_time).size
          when :active_goal_90_days
            owners_with_active_goal_in_90_days(week_end_date).size
          when :goal_check_in
            owners_with_check_in_during_week(week_start, week_end_date, reference_time).size
          when :completed_90_days
            owners_with_completion_in_90_days(week_end_date).size
          else
            0
          end
        end
      end

      def active_owner_ids(reference_time)
        goal_rows.filter_map do |owner_id, started_at, completed_at, deleted_at|
          next unless teammate_in_scope?(owner_id)
          next unless goal_active_at?(started_at, completed_at, deleted_at, reference_time)

          owner_id
        end.uniq
      end

      def owners_with_check_in_during_week(week_start, week_end_date, reference_time)
        week_range = week_start.beginning_of_day..week_end_date.end_of_day
        check_in_rows.filter_map do |owner_id, created_at, started_at, completed_at, deleted_at|
          next unless teammate_in_scope?(owner_id)
          next unless created_at && week_range.cover?(created_at)
          next unless goal_active_at?(started_at, completed_at, deleted_at, reference_time)

          owner_id
        end.uniq
      end

      def owners_with_completion_in_90_days(week_end_date)
        window_start = week_end_date - 89.days
        goal_rows.filter_map do |owner_id, _started_at, completed_at, _deleted_at|
          next unless teammate_in_scope?(owner_id)
          next if completed_at.blank?

          completed_date = completed_at.to_date
          next unless completed_date >= window_start && completed_date <= week_end_date

          owner_id
        end.uniq
      end

      # Unique owners whose goal was live for at least one day in the trailing
      # 90-day window ending Sunday (same window convention as completed_90_days).
      # Excludes deleted goals. Still-active, completed-within-window, and
      # started-within-window all qualify.
      def owners_with_active_goal_in_90_days(week_end_date)
        window_start = week_end_date - 89.days
        window_end_time = week_end_date.in_time_zone.end_of_day
        goal_rows.filter_map do |owner_id, started_at, completed_at, deleted_at|
          next unless teammate_in_scope?(owner_id)
          next unless goal_overlapped_window?(started_at, completed_at, deleted_at, window_start, window_end_time)

          owner_id
        end.uniq
      end

      def goal_active_at?(started_at, completed_at, deleted_at, reference_time)
        return false if deleted_at.present?
        return false if started_at.blank?

        started_at <= reference_time && (completed_at.nil? || completed_at > reference_time)
      end

      def goal_overlapped_window?(started_at, completed_at, deleted_at, window_start, window_end_time)
        return false if deleted_at.present?
        return false if started_at.blank?
        return false if started_at > window_end_time
        return false if completed_at.present? && completed_at.to_date < window_start

        true
      end

      def goal_rows
        @goal_rows ||= Goal
          .where(company: company, owner_type: 'CompanyTeammate')
          .pluck(:owner_id, :started_at, :completed_at, :deleted_at)
      end

      def check_in_rows
        @check_in_rows ||= GoalCheckIn
          .joins(:goal)
          .where(goals: { company_id: company.id, owner_type: 'CompanyTeammate' })
          .pluck(
            'goals.owner_id',
            'goal_check_ins.created_at',
            'goals.started_at',
            'goals.completed_at',
            'goals.deleted_at'
          )
      end
    end
  end
end
