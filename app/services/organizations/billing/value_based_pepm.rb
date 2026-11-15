# frozen_string_literal: true

module Organizations
  module Billing
    # Average value-per-employee from the Value page unit rates, for PEPM preview.
    class ValueBasedPepm
      APPROX_WEEKS_PER_MONTH = 4.3

      def initialize(organization)
        @organization = organization
        @drivers = ValueDrivers.new(organization)
      end

      def call(range: 90.days.ago..Time.current)
        total_value = @drivers.total_value(range)
        week_count = [
          ((range.end.to_date - range.begin.to_date).to_f / 7.0).ceil,
          1
        ].max
        teammate_count = CompanyTeammate.for_organization_hierarchy(@organization).employed.count

        per_employee_week =
          if week_count.positive? && teammate_count.positive?
            total_value.to_f / week_count / teammate_count
          end
        per_employee_month = per_employee_week && (per_employee_week * APPROX_WEEKS_PER_MONTH)

        {
          total_value: total_value.to_f,
          week_count: week_count,
          teammate_count: teammate_count,
          per_employee_week: per_employee_week,
          per_employee_month: per_employee_month,
          range_begin: range.begin.to_date,
          range_end: range.end.to_date
        }
      end
    end
  end
end
