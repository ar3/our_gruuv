# frozen_string_literal: true

module Organizations
  module Billing
    # Prior-prior / prior / current-period driver activity for OG Value Analysis.
    # Driver cells are activity counts; Total is overall PEPM (period value ÷ employed).
    # Third column is projected while the period is in progress; after it ends, actuals.
    class ValueAnalysisTable
      PeriodColumn = Struct.new(:key, :label, :starts_on, :ends_on, keyword_init: true)
      Cell = Struct.new(:activity_count, :teammate_count, :value_sum, keyword_init: true)
      DriverRow = Struct.new(:key, :label, :prior_prior, :prior, :current, keyword_init: true)
      TotalCell = Struct.new(:pepm, :value_sum, keyword_init: true)
      Result = Struct.new(
        :columns,
        :rows,
        :totals,
        :teammate_count,
        :projected,
        keyword_init: true
      ) do
        alias_method :projected?, :projected
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
        projected = current_range.end.to_date >= @as_of
        teammate_count = employed_teammate_count
        divisor = [teammate_count, 1].max

        prior_breakdown = prior_range ? indexed_breakdown(prior_range) : {}
        prior_prior_breakdown = prior_prior_range ? indexed_breakdown(prior_prior_range) : {}
        current_breakdown = projected ? {} : indexed_breakdown(current_range)

        rows = ValueDrivers::DRIVERS.map do |driver|
          unit_value = driver[:unit_value]
          prior_prior_cell = cell_from_breakdown(prior_prior_breakdown, driver[:key], prior_prior_range)
          prior_cell = cell_from_breakdown(prior_breakdown, driver[:key], prior_range)
          current_cell =
            if projected
              project_cell(prior_cell, prior_prior_cell, unit_value)
            else
              cell_from_breakdown(current_breakdown, driver[:key], current_range)
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
          columns: [
            PeriodColumn.new(
              key: :prior_prior,
              label: "Prior-prior period",
              starts_on: prior_prior_range&.begin,
              ends_on: prior_prior_range&.end&.to_date
            ),
            PeriodColumn.new(
              key: :prior,
              label: "Prior period",
              starts_on: prior_range&.begin,
              ends_on: prior_range&.end&.to_date
            ),
            PeriodColumn.new(
              key: projected ? :projected : :actual,
              label: projected ? "Projected this period" : "Actual this period",
              starts_on: current_range.begin,
              ends_on: current_range.end.to_date
            )
          ],
          rows: rows,
          totals: {
            prior_prior: total_cell_for(rows, :prior_prior, prior_prior_range, divisor),
            prior: total_cell_for(rows, :prior, prior_range, divisor),
            current: total_cell_for(rows, :current, true, divisor)
          },
          teammate_count: teammate_count,
          projected: projected
        )
      end

      private

      def period_range_for(due_on)
        return nil if due_on.blank?

        ends_on = NextDueDate.call(cadence: @cadence, from: due_on + 1.day) - 1.day
        due_on.to_date..ends_on.to_date
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

      def total_cell_for(rows, slot, range_present, divisor)
        return nil unless range_present

        value_sum = rows.sum { |row| row.public_send(slot)&.value_sum.to_f }
        TotalCell.new(
          pepm: (value_sum / divisor).round(2),
          value_sum: value_sum.round(2)
        )
      end
    end
  end
end
