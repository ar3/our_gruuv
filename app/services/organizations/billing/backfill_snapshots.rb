# frozen_string_literal: true

module Organizations
  module Billing
    # One-time bootstrap: create open historical invoices for past due dates
    # when value was delivered before billing existed.
    class BackfillSnapshots
      DEFAULT_COUNT = 6

      Result = Struct.new(:created_count, :skipped_reason, keyword_init: true)

      def self.call(organization:, count: DEFAULT_COUNT, as_of: Date.current)
        new(organization: organization, count: count, as_of: as_of).call
      end

      def initialize(organization:, count: DEFAULT_COUNT, as_of: Date.current)
        @organization = organization
        @count = count
        @as_of = as_of.to_date
        @setting = OrganizationBillingSetting.for_organization!(organization)
      end

      def call
        return Result.new(created_count: 0, skipped_reason: "already_has_invoices") if @organization.billing_invoices.exists?

        next_due = @setting.next_payment_due_on
        next_due = NextDueDate.call(cadence: @setting.cadence, from: @as_of) if next_due.blank? || next_due < @as_of

        due_dates = PreviousDueDates.call(
          cadence: @setting.cadence,
          before: next_due,
          count: @count
        ).select { |due_on| due_on - 1.week <= @as_of }

        return Result.new(created_count: 0, skipped_reason: "no_past_periods") if due_dates.empty?

        created = 0
        latest_pepm = nil

        ActiveRecord::Base.transaction do
          due_dates.reverse_each do |due_on|
            calculation_on = due_on - 1.week
            metrics = ValueBasedPepm.new(@organization).call(
              range: 90.days.ago(calculation_on.beginning_of_day)..calculation_on.end_of_day
            )
            pepm = discounted_pepm(metrics[:per_employee_month])
            teammate_count = metrics[:teammate_count].to_i
            value_delivered = metrics[:total_value].to_f
            amount_due = AmountDue.call(
              pepm: pepm,
              teammate_count: teammate_count,
              value_delivered: value_delivered,
              months: @setting.months_in_period
            )
            period_end = NextDueDate.call(cadence: @setting.cadence, from: due_on + 1.day) - 1.day

            @organization.billing_invoices.create!(
              status: "open",
              cadence: @setting.cadence,
              period_starts_on: due_on,
              period_ends_on: period_end,
              due_on: due_on,
              pepm: pepm,
              teammate_count: teammate_count,
              amount_due: amount_due,
              value_delivered_total: value_delivered,
              value_based_pepm: pepm
            )
            latest_pepm = pepm
            created += 1
          end

          @setting.update!(
            locked_pepm: latest_pepm,
            next_payment_due_on: next_due
          )
        end

        Result.new(created_count: created, skipped_reason: nil)
      end

      private

      def discounted_pepm(base_monthly)
        return 0.0 if base_monthly.nil?

        RoundDownToHalfDollar.call(base_monthly * (1.0 - @setting.discount_rate))
      end
    end
  end
end
