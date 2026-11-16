# frozen_string_literal: true

module Organizations
  module Billing
    # On calculation day (due − 1 week), lock PEPM and create an open invoice.
    class LockPepm
      Result = Struct.new(:invoice, :created?, :skipped_reason, :prior_pepm, keyword_init: true)

      def self.call(organization:, due_on: nil, as_of: Date.current)
        new(organization: organization, due_on: due_on, as_of: as_of).call
      end

      def initialize(organization:, due_on: nil, as_of: Date.current)
        @organization = organization
        @as_of = as_of.to_date
        @setting = OrganizationBillingSetting.for_organization!(organization)
        @due_on = (due_on || resolve_due_on).to_date
      end

      def call
        return skip("calculation_day_not_reached") if @as_of < calculation_on
        return existing_result if existing_invoice

        prior_pepm = @setting.locked_pepm
        invoice = nil

        ActiveRecord::Base.transaction do
          metrics = ValueBasedPepm.new(@organization).call(range: lookback_range)
          value_based_pepm = (metrics[:per_employee_month] || 0.0).to_f.round(2)
          pepm = discounted_pepm(metrics[:per_employee_month])
          teammate_count = metrics[:teammate_count].to_i
          value_delivered = metrics[:total_value].to_f
          amount_due = AmountDue.call(
            pepm: pepm,
            teammate_count: teammate_count,
            value_delivered: value_delivered,
            months: @setting.months_in_period
          )

          invoice = @organization.billing_invoices.create!(
            status: "open",
            cadence: @setting.cadence,
            period_starts_on: @due_on,
            period_ends_on: period_ends_on,
            due_on: @due_on,
            pepm: pepm,
            teammate_count: teammate_count,
            amount_due: amount_due,
            value_delivered_total: value_delivered,
            value_based_pepm: value_based_pepm
          )

          @setting.update!(
            locked_pepm: pepm,
            current_period_starts_on: @due_on,
            next_payment_due_on: @due_on
          )
        end

        Result.new(invoice: invoice, created?: true, skipped_reason: nil, prior_pepm: prior_pepm)
      rescue ActiveRecord::RecordNotUnique
        existing_result
      end

      private

      def calculation_on
        @due_on - 1.week
      end

      def resolve_due_on
        stored = @setting.next_payment_due_on
        return stored if stored.present? && stored >= @as_of

        NextDueDate.call(cadence: @setting.cadence, from: @as_of)
      end

      def existing_invoice
        @existing_invoice ||= @organization.billing_invoices.find_by(due_on: @due_on)
      end

      def existing_result
        Result.new(
          invoice: existing_invoice,
          created?: false,
          skipped_reason: "already_locked",
          prior_pepm: nil
        )
      end

      def skip(reason)
        Result.new(invoice: nil, created?: false, skipped_reason: reason, prior_pepm: nil)
      end

      def lookback_range
        90.days.ago(@as_of.beginning_of_day)..@as_of.end_of_day
      end

      def discounted_pepm(base_monthly)
        return 0.0 if base_monthly.nil?

        discounted = base_monthly * (1.0 - @setting.discount_rate)
        RoundDownToHalfDollar.call(discounted)
      end

      def period_ends_on
        next_due = NextDueDate.call(cadence: @setting.cadence, from: @due_on + 1.day)
        next_due - 1.day
      end
    end
  end
end
