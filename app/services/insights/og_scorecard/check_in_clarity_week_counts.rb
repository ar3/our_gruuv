# frozen_string_literal: true

module Insights
  module OgScorecard
    # Counts unique teammates in clear / blurred / obscured buckets per week (Sunday snapshot).
    class CheckInClarityWeekCounts
      def self.call(company:, week_starts:, preloaded_data: nil, teammate_ids: nil)
        new(company: company, week_starts: week_starts, preloaded_data: preloaded_data, teammate_ids: teammate_ids).call
      end

      def initialize(company:, week_starts:, preloaded_data: nil, teammate_ids: nil)
        @company = company
        @week_starts = week_starts
        @teammate_ids = teammate_ids
        @data = preloaded_data || CheckInDataPreloader.new(company, teammate_ids: teammate_ids).load
      end

      def call
        {
          all_check_ins_clear: counts_by_week(:clear),
          all_check_ins_blurred: counts_by_week(:blurred),
          all_check_ins_obscured: counts_by_week(:obscured)
        }
      end

      private

      attr_reader :company, :week_starts, :data, :teammate_ids

      def teammate_in_scope?(teammate_id)
        teammate_ids.nil? || teammate_ids.include?(teammate_id)
      end

      def counts_by_week(bucket)
        week_starts.index_with do |week_start|
          reference_time = (week_start + 6.days).in_time_zone.end_of_day
          active_teammate_ids(reference_time).count do |teammate_id|
            rollup_bucket(teammate_id, reference_time) == bucket
          end
        end
      end

      def active_teammate_ids(reference_time)
        data[:teammates].filter_map do |id, first_employed_at, last_terminated_at|
          next unless teammate_in_scope?(id)
          next unless employed?(first_employed_at, last_terminated_at, reference_time)

          id
        end
      end

      def employed?(first_employed_at, last_terminated_at, reference_time)
        return false if first_employed_at.blank?

        first_employed_at.to_time.in_time_zone <= reference_time &&
          (last_terminated_at.nil? || last_terminated_at.to_time.in_time_zone > reference_time)
      end

      def rollup_bucket(teammate_id, reference_time)
        ClarityLevel.rollup_bucket(clarity_levels_for(teammate_id, reference_time))
      end

      def clarity_levels_for(teammate_id, reference_time)
        levels = []

        if employment_tenure_at(teammate_id, reference_time)
          levels << clarity_at(reference_time, latest_at_or_before(data[:position_finalized_at][teammate_id], reference_time))
        end

        required_assignment_ids(teammate_id, reference_time).each do |assignment_id|
          times = data[:assignment_finalized_at][[teammate_id, assignment_id]]
          levels << clarity_at(reference_time, latest_at_or_before(times, reference_time))
        end

        data[:aspiration_ids].each do |aspiration_id|
          times = data[:aspiration_finalized_at][[teammate_id, aspiration_id]]
          levels << clarity_at(reference_time, latest_at_or_before(times, reference_time))
        end

        levels
      end

      def clarity_at(reference_time, finalized_at)
        ClarityLevel.from_finalized_at(finalized_at, reference_time: reference_time)
      end

      def latest_at_or_before(times, reference_time)
        return nil if times.blank?

        times.select { |t| t.present? && t <= reference_time }.max
      end

      def required_assignment_ids(teammate_id, reference_time)
        assignment_ids = Set.new

        tenure = employment_tenure_at(teammate_id, reference_time)
        if tenure
          _tid, _start, _end, position_id = tenure
          Array(data[:required_assignment_ids_by_position][position_id]).each { |aid| assignment_ids << aid }
        end

        data[:assignment_tenures].each do |tid, assignment_id, started_at, ended_at, energy|
          next unless tid == teammate_id
          next unless tenure_active?(started_at, ended_at, reference_time)
          next unless energy.to_i.positive?

          assignment_ids << assignment_id
        end

        assignment_ids.to_a
      end

      def employment_tenure_at(teammate_id, reference_time)
        ref_date = reference_time.to_date
        data[:employment_tenures]
          .select { |tid, started_at, ended_at, _pos| tid == teammate_id && tenure_active?(started_at, ended_at, reference_time) }
          .max_by { |row| row[1] }
      end

      def tenure_active?(started_at, ended_at, reference_time)
        return false if started_at.blank?

        ref_date = reference_time.to_date
        start_date = started_at.to_date
        return false if start_date > ref_date

        ended_at.nil? || ended_at.to_date > ref_date
      end
    end
  end
end
