# frozen_string_literal: true

module Insights
  module OgScorecard
    # Weekly counts of teammates who finalized a clarity check-in (position,
    # assignment, or aspiration) during the week or ever through that Sunday.
    class ClarityCheckInWeekCounts
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
          unique_teammates_check_in_finalized_this_week: counts_by_week(:this_week),
          unique_teammates_check_in_finalized_all_time: counts_by_week(:all_time)
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
          case mode
          when :this_week
            teammates_with_finalization_during_week(week_start, week_end_date).size
          when :all_time
            active_ids = active_teammate_ids_for_week(week_end_date)
            teammates_with_finalization_on_or_before(week_end_date, active_ids).size
          else
            0
          end
        end
      end

      def teammates_with_finalization_during_week(week_start, week_end_date)
        week_range = week_start.beginning_of_day..week_end_date.end_of_day
        finalized_rows.filter_map do |teammate_id, finalized_at|
          next unless teammate_in_scope?(teammate_id)
          next unless finalized_at && week_range.cover?(finalized_at)

          teammate_id
        end.uniq
      end

      def teammates_with_finalization_on_or_before(week_end_date, active_ids)
        week_end_time = week_end_date.in_time_zone.end_of_day
        active_set = active_ids.to_set
        finalized_rows.filter_map do |teammate_id, finalized_at|
          next unless teammate_in_scope?(teammate_id)
          next unless active_set.include?(teammate_id)
          next unless finalized_at && finalized_at <= week_end_time

          teammate_id
        end.uniq
      end

      def active_teammate_ids_for_week(week_ending_on)
        EngagementHealth::WeeklyRollupTeammateScope.active_teammate_ids(
          organization: company,
          week_ending_on: week_ending_on,
          teammate_ids: teammate_ids
        )
      end

      def finalized_rows
        @finalized_rows ||= begin
          ids = scoped_teammate_ids
          return [] if ids.empty?

          company_ids = company.self_and_descendants.pluck(:id)
          rows = []

          rows.concat(
            PositionCheckIn
              .closed
              .where(teammate_id: ids)
              .pluck(:teammate_id, :official_check_in_completed_at)
          )

          rows.concat(
            AssignmentCheckIn
              .closed
              .joins(:assignment)
              .where(teammate_id: ids, assignments: { company_id: company_ids })
              .pluck(:teammate_id, :official_check_in_completed_at)
          )

          rows.concat(
            AspirationCheckIn
              .closed
              .joins(:aspiration)
              .merge(Aspiration.unscoped.where(company_id: company_ids))
              .where(teammate_id: ids)
              .pluck(:teammate_id, :official_check_in_completed_at)
          )

          rows
        end
      end

      def scoped_teammate_ids
        @scoped_teammate_ids ||= begin
          scope = CompanyTeammate.for_organization_hierarchy(company).where.not(first_employed_at: nil)
          scope = scope.where(id: teammate_ids) if teammate_ids
          scope.pluck(:id)
        end
      end
    end
  end
end
