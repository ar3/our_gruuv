# frozen_string_literal: true

module Organizations
  module Billing
    # Prior / current-period driver activity for OG Value Analysis.
    # Driver cells are activity counts; Total is Value-page PEPM for that date range.
    # Each column has its own status vs as_of:
    # - upcoming: period not started → trend projection (current column only)
    # - in_progress: so-far actuals (+ / pace) for any incomplete column
    # - complete: full-period actuals
    class ValueAnalysisTable
      PeriodColumn = Struct.new(
        :key,
        :label,
        :starts_on,
        :ends_on,
        :status,
        :period_progress,
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
      DriverRow = Struct.new(:key, :label, :prior_prior, :prior, :current, keyword_init: true)
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
          column_for(:current)&.upcoming?
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
        prior_due = PreviousDueDates.call(cadence: @cadence, before: @period_due_on, count: 1).first
        prior_prior_due = prior_due && PreviousDueDates.call(cadence: @cadence, before: prior_due, count: 1).first

        prior_range = period_range_for(prior_due)
        prior_prior_range = period_range_for(prior_prior_due)
        current_range = period_range_for(@period_due_on)
        teammate_count = employed_teammate_count

        prior_prior_col = build_column(:prior_prior, prior_prior_range)
        prior_col = build_column(:prior, prior_range)
        current_col = build_column(:current, current_range)

        prior_prior_display = display_breakdown(prior_prior_range, prior_prior_col.status)
        prior_display = display_breakdown(prior_range, prior_col.status)
        current_display = display_breakdown(current_range, current_col.status)

        rows = ValueDrivers::DRIVERS.map do |driver|
          prior_prior_cell = cell_from_breakdown(prior_prior_display, driver[:key], prior_prior_range)
          prior_cell = cell_from_breakdown(prior_display, driver[:key], prior_range)
          current_cell =
            if current_col.upcoming?
              # If the prior period is still open, pace-project it to 100% before
              # using it as the baseline for the future-period trend calculation.
              prior_baseline = completed_or_pace_projected_cell(
                prior_cell,
                prior_col,
                driver[:unit_value]
              )
              prior_prior_baseline = completed_or_pace_projected_cell(
                prior_prior_cell,
                prior_prior_col,
                driver[:unit_value]
              )
              project_cell(prior_baseline, prior_prior_baseline, driver[:unit_value])
            else
              cell_from_breakdown(current_display, driver[:key], true)
            end

          DriverRow.new(
            key: driver[:key],
            label: driver[:label],
            prior_prior: prior_prior_cell,
            prior: prior_cell,
            current: current_cell
          )
        end

        Result.new(
          columns: [prior_prior_col, prior_col, current_col],
          rows: rows,
          totals: {
            prior_prior: total_for_column(prior_prior_range, prior_prior_col, rows, :prior_prior, teammate_count),
            prior: total_for_column(prior_range, prior_col, rows, :prior, teammate_count),
            current: total_for_column(current_range, current_col, rows, :current, teammate_count)
          },
          teammate_count: teammate_count
        )
      end

      private

      def build_column(key, range)
        return PeriodColumn.new(key: key, label: nil, starts_on: nil, ends_on: nil, status: :complete, period_progress: 1.0) if range.blank?

        status = status_for(range)
        PeriodColumn.new(
          key: key,
          label: nil,
          starts_on: range.begin.to_date,
          ends_on: range.end.to_date,
          status: status,
          period_progress: period_progress_ratio(range, status)
        )
      end

      def status_for(range)
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
