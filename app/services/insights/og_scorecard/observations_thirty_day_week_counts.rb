# frozen_string_literal: true

module Insights
  module OgScorecard
    # Unique teammates who published or were named in a published OGO in the rolling 30 days ending each Sunday.
    class ObservationsThirtyDayWeekCounts
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
          unique_ogo_publishers_30_days: counts_by_week(:publishers),
          unique_ogo_observees_30_days: counts_by_week(:observees)
        }
      end

      private

      attr_reader :company, :week_starts, :teammate_ids

      def teammate_in_scope?(teammate_id)
        teammate_id.present? && (teammate_ids.nil? || teammate_ids.include?(teammate_id))
      end

      def counts_by_week(mode)
        week_starts.index_with do |week_start|
          window_start, window_end = thirty_day_window_for(week_start)
          ids = case mode
                when :publishers
                  publisher_teammate_ids_in_window(window_start, window_end)
                when :observees
                  observee_teammate_ids_in_window(window_start, window_end)
                else
                  []
                end
          ids.uniq.size
        end
      end

      def thirty_day_window_for(week_start)
        week_end_date = week_start + 6.days
        window_start = (week_end_date - 29.days).in_time_zone.beginning_of_day
        window_end = week_end_date.in_time_zone.end_of_day
        [window_start, window_end]
      end

      def publisher_teammate_ids_in_window(window_start, window_end)
        publisher_rows.filter_map do |published_at, observer_person_id|
          next unless in_window?(published_at, window_start, window_end)

          teammate_id = teammate_id_by_person_id[observer_person_id]
          teammate_id if teammate_in_scope?(teammate_id)
        end
      end

      def observee_teammate_ids_in_window(window_start, window_end)
        observee_rows.filter_map do |published_at, teammate_id|
          next unless in_window?(published_at, window_start, window_end)

          teammate_id if teammate_in_scope?(teammate_id)
        end
      end

      def in_window?(published_at, window_start, window_end)
        published_at.present? && published_at >= window_start && published_at <= window_end
      end

      def publisher_rows
        @publisher_rows ||= observation_scope.pluck(:published_at, :observer_id)
      end

      def observee_rows
        @observee_rows ||= Observee
          .joins(:observation)
          .merge(observation_scope)
          .pluck('observations.published_at', 'observees.teammate_id')
      end

      def observation_scope
        @observation_scope ||= Observation
          .for_company(company)
          .not_soft_deleted
          .published
          .where(published_at: preload_range)
      end

      def preload_range
        first_week = week_starts.min
        last_week = week_starts.max
        range_start = (first_week + 6.days - 29.days).in_time_zone.beginning_of_day
        range_end = (last_week + 6.days).in_time_zone.end_of_day
        range_start..range_end
      end

      def teammate_id_by_person_id
        @teammate_id_by_person_id ||= begin
          person_ids = publisher_rows.map(&:last).compact.uniq
          return {} if person_ids.empty?

          CompanyTeammate
            .for_organization_hierarchy(company)
            .where(person_id: person_ids)
            .pluck(:person_id, :id)
            .group_by(&:first)
            .transform_values { |pairs| pairs.map(&:last).last }
        end
      end
    end
  end
end
