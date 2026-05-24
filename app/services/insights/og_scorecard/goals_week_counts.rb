# frozen_string_literal: true

module Insights
  module OgScorecard
    # Weekly goal metrics: active owners, goal check-ins, and recent completions.
    class GoalsWeekCounts
      def self.call(company:, week_starts:)
        new(company: company, week_starts: week_starts).call
      end

      def initialize(company:, week_starts:)
        @company = company
        @week_starts = week_starts
      end

      def call
        {
          unique_teammates_active_goal: counts_by_week(:active_goal),
          unique_teammates_goal_check_in_this_week: counts_by_week(:goal_check_in),
          unique_teammates_completed_goal_90_days: counts_by_week(:completed_90_days)
        }
      end

      private

      attr_reader :company, :week_starts

      def counts_by_week(mode)
        week_starts.index_with do |week_start|
          week_end_date = week_start + 6.days
          reference_time = week_end_date.in_time_zone.end_of_day
          case mode
          when :active_goal
            active_owner_ids(reference_time).size
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
          next unless goal_active_at?(started_at, completed_at, deleted_at, reference_time)

          owner_id
        end.uniq
      end

      def owners_with_check_in_during_week(week_start, week_end_date, reference_time)
        week_range = week_start.beginning_of_day..week_end_date.end_of_day
        check_in_rows.filter_map do |owner_id, created_at, started_at, completed_at, deleted_at|
          next unless created_at && week_range.cover?(created_at)
          next unless goal_active_at?(started_at, completed_at, deleted_at, reference_time)

          owner_id
        end.uniq
      end

      def owners_with_completion_in_90_days(week_end_date)
        window_start = week_end_date - 89.days
        goal_rows.filter_map do |owner_id, _started_at, completed_at, _deleted_at|
          next if completed_at.blank?

          completed_date = completed_at.to_date
          next unless completed_date >= window_start && completed_date <= week_end_date

          owner_id
        end.uniq
      end

      def goal_active_at?(started_at, completed_at, deleted_at, reference_time)
        return false if deleted_at.present?
        return false if started_at.blank?

        started_at <= reference_time && (completed_at.nil? || completed_at > reference_time)
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
