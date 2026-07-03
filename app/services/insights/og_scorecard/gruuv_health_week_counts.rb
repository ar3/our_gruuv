# frozen_string_literal: true

module Insights
  module OgScorecard
    # Population counts per week from weekly rollups (completed weeks) and the
    # live engagement_health_statuses cache (current in-progress week).
    class GruuvHealthWeekCounts
      METRIC_KEY_PREFIX = "gruuv_health_"
      Result = Data.define(:counts, :backfill_enqueued)

      def self.call(company:, week_starts:, teammate_ids: nil)
        new(company: company, week_starts: week_starts, teammate_ids: teammate_ids).call
      end

      def initialize(company:, week_starts:, teammate_ids: nil)
        @company = company
        @week_starts = week_starts
        @teammate_ids = teammate_ids
      end

      def call
        counts = empty_counts
        backfill_weeks = []
        live_cache_backfill_enqueued = false

        week_starts.each do |week_start|
          week_ending_on = week_start + 6.days
          active_ids = active_teammate_ids_for_week(week_ending_on)
          next if active_ids.empty?

          if live_week?(week_ending_on)
            live_cache_backfill_enqueued ||= apply_live_counts(counts, week_start, active_ids)
          else
            if rollup_week_incomplete?(week_ending_on)
              backfill_weeks << week_ending_on
            end
            apply_rollup_counts(counts, week_start, week_ending_on, active_ids)
          end
        end

        backfill_enqueued = enqueue_backfill(backfill_weeks) || live_cache_backfill_enqueued

        Result.new(counts: counts, backfill_enqueued: backfill_enqueued)
      end

      def self.metric_key(category, status)
        "#{METRIC_KEY_PREFIX}#{category}_#{status}"
      end

      private

      attr_reader :company, :week_starts, :teammate_ids

      def empty_counts
        EngagementHealth::CATEGORIES.each_with_object({}) do |category, memo|
          EngagementHealth::STATUSES.each do |status|
            memo[self.class.metric_key(category, status)] = week_starts.index_with { 0 }
          end
        end
      end

      def live_week?(week_ending_on)
        week_ending_on >= Date.current
      end

      def rollup_week_incomplete?(week_ending_on)
        !EngagementHealth::WeeklyRollupCompleteness.complete?(
          organization: company,
          week_ending_on: week_ending_on,
          teammate_ids: teammate_ids
        )
      end

      def active_teammate_ids_for_week(week_ending_on)
        EngagementHealth::WeeklyRollupTeammateScope.active_teammate_ids(
          organization: company,
          week_ending_on: week_ending_on,
          teammate_ids: teammate_ids
        )
      end

      def apply_live_counts(counts, week_start, active_ids)
        statuses_by_teammate, backfill_enqueued = live_category_statuses_for(active_ids)

        EngagementHealth::CATEGORIES.each do |category|
          EngagementHealth::STATUSES.each do |status|
            count = active_ids.count { |teammate_id| statuses_by_teammate.dig(teammate_id, category) == status }
            key = metric_key(category, status)
            counts[key][week_start] = count if counts.key?(key)
          end
        end

        backfill_enqueued
      end

      def live_category_statuses_for(active_ids)
        rows = EngagementHealthStatus
          .category_rollups
          .where(organization: company, teammate_id: active_ids)
          .pluck(:teammate_id, :category, :status)

        statuses_by_teammate = rows.each_with_object({}) do |(teammate_id, category, status), memo|
          (memo[teammate_id] ||= {})[category] = status
        end

        missing_ids = EngagementHealth::LiveCacheCompleteness.missing_teammate_ids(
          organization: company,
          teammate_ids: active_ids
        )
        return [statuses_by_teammate, false] if missing_ids.empty?

        backfill_enqueued = enqueue_live_cache_backfill(missing_ids)

        CompanyTeammate.where(id: missing_ids).find_each do |teammate|
          EngagementHealth::Calculator
            .call(teammate: teammate, organization: company)
            .each do |row|
              next unless row[:level] == "category"

              (statuses_by_teammate[teammate.id] ||= {})[row[:category]] = row[:status]
            end
        end

        [statuses_by_teammate, backfill_enqueued]
      end

      def enqueue_live_cache_backfill(teammate_ids)
        ids = teammate_ids.uniq
        return false if ids.empty?

        EngagementHealthLiveCacheBackfillJob.perform_later(company.id, ids)
        true
      end

      def apply_rollup_counts(counts, week_start, week_ending_on, active_ids)
        grouped = EngagementHealthWeeklyRollup
          .where(organization: company, week_ending_on: week_ending_on, teammate_id: active_ids)
          .group(:category, :status)
          .count

        grouped.each do |(category, status), count|
          key = metric_key(category, status)
          counts[key][week_start] += count if counts.key?(key)
        end
      end

      def enqueue_backfill(week_ending_ons)
        weeks = week_ending_ons.uniq
        return false if weeks.empty?

        EngagementHealthWeeklyRollupBackfillJob.perform_later(company.id, weeks.map(&:iso8601))
        true
      end

      def metric_key(category, status)
        self.class.metric_key(category, status)
      end
    end
  end
end
