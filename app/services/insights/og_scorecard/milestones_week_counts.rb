# frozen_string_literal: true

module Insights
  module OgScorecard
    # Weekly counts for ability milestones earned (this week and rolling 90 days ending Sunday).
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
          unique_teammates_milestone_this_week: counts_by_week(:unique_this_week),
          milestones_earned_this_week: counts_by_week(:total_this_week),
          unique_teammates_milestone_90_days: counts_by_week(:unique_90_days),
          milestones_earned_90_days: counts_by_week(:total_90_days)
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
          when :unique_this_week, :unique_90_days
            rows.map(&:first).uniq.size
          when :total_this_week, :total_90_days
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
        else
          []
        end
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
