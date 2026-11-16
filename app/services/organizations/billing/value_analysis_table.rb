# frozen_string_literal: true

module Organizations
  module Billing
    # Lookback / current-period / next-period driver activity for OG Value Analysis.
    # First data column is always the PEPM lookback (~90 days), matching how PEPM
    # is calculated — not a cadence-length prior billable period.
    #
    # Driver cells store period-native activity. Views multiply by
    # PeriodColumn#activity_scale so monthly/semiannual columns compare to the
    # 90-day lookback. Total PEPM uses real date-range Value-page math (already monthly).
    class ValueAnalysisTable
      LOOKBACK_DAYS = 90

      PeriodColumn = Struct.new(
        :key,
        :label,
        :starts_on,
        :ends_on,
        :status,
        :period_progress,
        :activity_scale,
        keyword_init: true
      ) do
        def upcoming?
          status == :upcoming
        end

        def in_progress?
          status == :in_progress
        end

        def complete?
          status == :complete
        end
      end
      Cell = Struct.new(:activity_count, :teammate_count, :value_sum, keyword_init: true)
      DriverRow = Struct.new(:key, :label, :lookback, :current, :future, keyword_init: true)
      TotalCell = Struct.new(
        :pepm,
        :value_sum,
        :week_count,
        :teammate_count,
        :per_employee_week,
        keyword_init: true
      )
      Result = Struct.new(
        :columns,
        :rows,
        :totals,
        :teammate_count,
        keyword_init: true
      ) do
        def column_for(key)
          columns.find { |column| column.key == key }
        end

        def upcoming?
          column_for(:current)&.upcoming? || column_for(:future)&.upcoming?
        end

        def in_progress?
          columns.any?(&:in_progress?)
        end

        def complete?
          columns.all? { |column| column.starts_on.nil? || column.complete? }
        end

        def projected?
          !complete?
        end

        def any_incomplete?
          columns.any? { |column| column.in_progress? || column.upcoming? }
        end
      end

      def self.call(organization:, cadence:, period_due_on:, as_of: Date.current)
        new(
          organization: organization,
          cadence: cadence,
          period_due_on: period_due_on,
          as_of: as_of
        ).call
      end

      def initialize(organization:, cadence:, period_due_on:, as_of: Date.current)
        @organization = organization
        @cadence = cadence
        @period_due_on = period_due_on.to_date
        @as_of = as_of.to_date
        @drivers = ValueDrivers.new(organization)
      end

      def call
        lookback_range = lookback_range_for_period
        prior_lookback_range = prior_lookback_range_for(lookback_range)
        current_range = period_range_for(@period_due_on)
        future_due = NextDueDate.call(cadence: @cadence, from: @period_due_on + 1.day)
        future_range = period_range_for(future_due)
        teammate_count = employed_teammate_count

        lookback_col = build_column(
          :lookback,
          lookback_range,
          activity_scale: 1.0,
          label: "Lookback"
        )
        current_col = build_column(
          :current,
          current_range,
          activity_scale: activity_scale_for(lookback_range, current_range)
        )
        future_col = build_column(
          :future,
          future_range,
          activity_scale: activity_scale_for(lookback_range, future_range)
        )

        lookback_display = display_breakdown(lookback_range, lookback_col.status)
        prior_lookback_display = display_breakdown(
          prior_lookback_range,
          status_for(prior_lookback_range)
        )
        current_display = display_breakdown(current_range, current_col.status)

        rows = ValueDrivers::DRIVERS.map do |driver|
          lookback_cell = cell_from_breakdown(lookback_display, driver[:key], lookback_range)
          prior_lookback_cell = cell_from_breakdown(
            prior_lookback_display,
            driver[:key],
            prior_lookback_range
          )

          current_cell =
            if current_col.upcoming?
              project_from_lookback(
                lookback_cell: lookback_cell,
                prior_lookback_cell: prior_lookback_cell,
                lookback_range: lookback_range,
                target_range: current_range,
                unit_value: driver[:unit_value]
              )
            else
              cell_from_breakdown(current_display, driver[:key], current_range)
            end

          future_cell =
            if future_col.upcoming?
              current_baseline =
                if current_col.upcoming?
                  current_cell
                else
                  completed_or_pace_projected_cell(
                    cell_from_breakdown(current_display, driver[:key], current_range),
                    current_col,
                    driver[:unit_value]
                  )
                end
              lookback_as_current = rescale_cell(
                lookback_cell,
                day_count(current_range).to_f / day_count(lookback_range),
                driver[:unit_value]
              )
              projected_current = project_cell(
                current_baseline,
                lookback_as_current,
                driver[:unit_value]
              )
              rescale_cell(
                projected_current,
                day_count(future_range).to_f / day_count(current_range),
                driver[:unit_value]
              )
            else
              cell_from_breakdown(
                display_breakdown(future_range, future_col.status),
                driver[:key],
                future_range
              )
            end

          DriverRow.new(
            key: driver[:key],
            label: driver[:label],
            lookback: lookback_cell,
            current: current_cell,
            future: future_cell
          )
        end

        Result.new(
          columns: [lookback_col, current_col, future_col],
          rows: rows,
          totals: {
            lookback: total_for_column(lookback_range, lookback_col, rows, :lookback, teammate_count),
            current: total_for_column(current_range, current_col, rows, :current, teammate_count),
            future: total_for_column(future_range, future_col, rows, :future, teammate_count)
          },
          teammate_count: teammate_count
        )
      end

      private

      def lookback_range_for_period
        calculation_on = @period_due_on - 1.week
        ends_on = [@as_of, calculation_on].min
        starts_on = ends_on - LOOKBACK_DAYS.days
        starts_on..ends_on
      end

      def prior_lookback_range_for(lookback_range)
        ends_on = lookback_range.begin.to_date - 1.day
        starts_on = ends_on - LOOKBACK_DAYS.days
        starts_on..ends_on
      end

      def build_column(key, range, activity_scale:, label: nil)
        if range.blank?
          return PeriodColumn.new(
            key: key,
            label: label,
            starts_on: nil,
            ends_on: nil,
            status: :complete,
            period_progress: 1.0,
            activity_scale: 1.0
          )
        end

        status = status_for_column(key, range)
        PeriodColumn.new(
          key: key,
          label: label,
          starts_on: range.begin.to_date,
          ends_on: range.end.to_date,
          status: status,
          period_progress: period_progress_ratio(range, status),
          activity_scale: activity_scale.to_f
        )
      end

      # Lookback ending today is the PEPM window in full — treat as complete.
      def status_for_column(key, range)
        if key == :lookback && @as_of >= range.end.to_date
          :complete
        else
          status_for(range)
        end
      end

      def activity_scale_for(lookback_range, period_range)
        return 1.0 if lookback_range.blank? || period_range.blank?

        period_days = day_count(period_range)
        return 1.0 if period_days <= 0

        day_count(lookback_range).to_f / period_days
      end

      def day_count(range)
        return 0 if range.blank?

        (range.end.to_date - range.begin.to_date).to_i + 1
      end

      def status_for(range)
        return :complete if range.blank?

        starts_on = range.begin.to_date
        ends_on = range.end.to_date
        if @as_of < starts_on
          :upcoming
        elsif @as_of <= ends_on
          :in_progress
        else
          :complete
        end
      end

      def period_range_for(due_on)
        return nil if due_on.blank?

        ends_on = NextDueDate.call(cadence: @cadence, from: due_on + 1.day) - 1.day
        due_on.to_date..ends_on.to_date
      end

      def clipped_range(range)
        ends_on = [@as_of, range.end.to_date].min
        range.begin.to_date..ends_on
      end

      def period_progress_ratio(range, status)
        return 0.0 if status == :upcoming
        return 1.0 if status == :complete

        starts_on = range.begin.to_date
        ends_on = range.end.to_date
        total_days = (ends_on - starts_on).to_i + 1
        return 1.0 if total_days <= 0

        elapsed_days = (@as_of - starts_on).to_i + 1
        elapsed_days = [[elapsed_days, 0].max, total_days].min
        elapsed_days.to_f / total_days
      end

      def display_breakdown(range, status)
        return {} if range.blank?

        query_range =
          case status
          when :in_progress then clipped_range(range)
          when :complete then range
          else
            return {}
          end
        indexed_breakdown(query_range)
      end

      def indexed_breakdown(range)
        @drivers.breakdown(range).index_by { |row| row[:key] }
      end

      def employed_teammate_count
        CompanyTeammate.for_organization_hierarchy(@organization).employed.count
      end

      def cell_from_breakdown(breakdown, key, range_present)
        return nil unless range_present

        row = breakdown[key] || {}
        Cell.new(
          activity_count: row[:activity_count].to_i,
          teammate_count: row[:teammate_count].to_i,
          value_sum: row[:value_sum].to_f
        )
      end

      def rescale_cell(cell, factor, unit_value)
        return nil if cell.nil?
        return cell if factor.nil? || (factor - 1.0).abs < 0.0001

        activity = (cell.activity_count.to_f * factor).round
        teammates = (cell.teammate_count.to_f * factor).round
        Cell.new(
          activity_count: activity,
          teammate_count: teammates,
          value_sum: (activity * unit_value).round(2)
        )
      end

      def completed_or_pace_projected_cell(cell, column, unit_value)
        return nil if cell.nil?
        return cell unless column.in_progress?

        pace_projected_cell(cell, column.period_progress, unit_value)
      end

      def pace_projected_cell(cell, period_progress, unit_value)
        return nil if cell.nil?
        return cell if period_progress.to_f <= 0

        activity = (cell.activity_count.to_f / period_progress).round
        teammates = (cell.teammate_count.to_f / period_progress).round
        Cell.new(
          activity_count: activity,
          teammate_count: teammates,
          value_sum: (activity * unit_value).round(2)
        )
      end

      def project_from_lookback(lookback_cell:, prior_lookback_cell:, lookback_range:, target_range:, unit_value:)
        return nil if lookback_cell.nil? || target_range.blank? || lookback_range.blank?

        projected_lookback = project_cell(lookback_cell, prior_lookback_cell, unit_value)
        rescale_cell(
          projected_lookback,
          day_count(target_range).to_f / day_count(lookback_range),
          unit_value
        )
      end

      def project_cell(prior_cell, prior_prior_cell, unit_value)
        return nil if prior_cell.nil?

        activity = project_number(prior_cell.activity_count, prior_prior_cell&.activity_count)
        teammates = project_number(prior_cell.teammate_count, prior_prior_cell&.teammate_count)
        Cell.new(
          activity_count: activity,
          teammate_count: teammates,
          value_sum: (activity * unit_value).round(2)
        )
      end

      def project_number(prior_value, prior_prior_value)
        return prior_value.to_i if prior_prior_value.nil?

        delta = prior_value.to_i - prior_prior_value.to_i
        if delta.positive?
          prior_value.to_i + delta
        else
          prior_value.to_i
        end
      end

      def total_for_column(range, column, rows, slot, teammate_count)
        return nil if range.blank?

        if column.upcoming?
          value_sum = rows.sum { |row| row.public_send(slot)&.value_sum.to_f }
          metrics = ValueBasedPepm.metrics(
            value_sum: value_sum,
            range: range,
            teammate_count: teammate_count
          )
          return total_cell_from_metrics(metrics, teammate_count)
        end

        query_range = column.in_progress? ? clipped_range(range) : range
        metrics = ValueBasedPepm.new(@organization).call(range: query_range)
        total_cell_from_metrics(metrics, teammate_count)
      end

      def total_cell_from_metrics(metrics, teammate_count)
        pepm = metrics[:per_employee_month]
        return nil if pepm.nil?

        TotalCell.new(
          pepm: pepm.round(2),
          value_sum: metrics[:total_value].to_f.round(2),
          week_count: metrics[:week_count],
          teammate_count: teammate_count,
          per_employee_week: metrics[:per_employee_week]&.round(4)
        )
      end
    end
  end
end
