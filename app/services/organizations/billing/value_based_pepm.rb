# frozen_string_literal: true

module Organizations
  module Billing
    # Value-page PEPM math: total value ÷ weeks ÷ active teammates, then ≈ monthly.
    # Week counting matches ValueBillingController#build_week_dates (uniq beginning_of_week).
    class ValueBasedPepm
      APPROX_WEEKS_PER_MONTH = 4.3

      def self.week_count_for(range)
        return 0 if range.blank?

        (range.begin.to_date..range.end.to_date)
          .map(&:beginning_of_week)
          .uniq
          .size
      end

      # Same formula as ValueBillingController#annualized_value_metrics (+ monthly approx).
      def self.metrics(value_sum:, range:, teammate_count:)
        week_count = week_count_for(range)
        value_sum = value_sum.to_f
        teammate_count = teammate_count.to_i

        result = {
          total_value: value_sum,
          week_count: week_count,
          teammate_count: teammate_count,
          per_employee_week: nil,
          per_employee_month: nil,
          range_begin: range&.begin&.to_date,
          range_end: range&.end&.to_date
        }
        return result unless week_count.positive? && teammate_count.positive?

        per_employee_week = value_sum / week_count / teammate_count
        result.merge(
          per_employee_week: per_employee_week,
          per_employee_month: per_employee_week * APPROX_WEEKS_PER_MONTH
        )
      end

      def initialize(organization)
        @organization = organization
        @drivers = ValueDrivers.new(organization)
      end

      def call(range: 90.days.ago..Time.current)
        teammate_count = CompanyTeammate.for_organization_hierarchy(@organization).employed.count
        self.class.metrics(
          value_sum: @drivers.total_value(range),
          range: range,
          teammate_count: teammate_count
        )
      end
    end
  end
end
