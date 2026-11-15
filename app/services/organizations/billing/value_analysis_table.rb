# frozen_string_literal: true

module Organizations
  module Billing
    # Prior-prior / prior / current-period per-employee value by driver for OG Value Analysis.
    # Third column is projected while the period is in progress; after it ends, actuals.
    class ValueAnalysisTable
      PeriodColumn = Struct.new(:key, :label, :starts_on, :ends_on, keyword_init: true)
      DriverRow = Struct.new(
        :key,
        :label,
        :prior_prior_value,
        :prior_prior_total,
        :prior_value,
        :prior_total,
        :current_value,
        :current_total,
        keyword_init: true
      )
      Result = Struct.new(
        :columns,
        :rows,
        :totals,
        :total_sums,
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
        divisor = per_employee_divisor
        projected = current_range.end.to_date >= @as_of

        prior_breakdown = prior_range ? indexed_breakdown(prior_range) : {}
        prior_prior_breakdown = prior_prior_range ? indexed_breakdown(prior_prior_range) : {}
        current_breakdown = projected ? {} : indexed_breakdown(current_range)
        teammate_count = employed_teammate_count

        rows = ValueDrivers::DRIVERS.map do |driver|
          prior_total = prior_range ? prior_breakdown.dig(driver[:key], :value_sum).to_f : nil
          prior_prior_total = prior_prior_range ? prior_prior_breakdown.dig(driver[:key], :value_sum).to_f : nil
          prior_value = prior_total && per_employee(prior_total, divisor)
          prior_prior_value = prior_prior_total && per_employee(prior_prior_total, divisor)

          if projected
            current_value = project(prior_value, prior_prior_value)
            current_total = current_value && (current_value * divisor).round(2)
          else
            current_total = current_breakdown.dig(driver[:key], :value_sum).to_f
            current_value = per_employee(current_total, divisor)
          end

          DriverRow.new(
            key: driver[:key],
            label: driver[:label],
            prior_prior_value: prior_prior_value,
            prior_prior_total: prior_prior_total,
            prior_value: prior_value,
            prior_total: prior_total,
            current_value: current_value,
            current_total: current_total
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
            prior_prior: prior_prior_range && rows.sum { |row| row.prior_prior_value.to_f },
            prior: prior_range && rows.sum { |row| row.prior_value.to_f },
            current: rows.sum { |row| row.current_value.to_f }
          },
          total_sums: {
            prior_prior: prior_prior_range && rows.sum { |row| row.prior_prior_total.to_f },
            prior: prior_range && rows.sum { |row| row.prior_total.to_f },
            current: rows.sum { |row| row.current_total.to_f }
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

      def per_employee_divisor
        [employed_teammate_count, 1].max
      end

      def per_employee(total, divisor)
        (total.to_f / divisor).round(2)
      end

      def project(prior_value, prior_prior_value)
        return nil if prior_value.nil?

        if prior_prior_value && (prior_value - prior_prior_value).positive?
          (prior_value + (prior_value - prior_prior_value)).round(2)
        else
          prior_value
        end
      end
    end
  end
end
