# frozen_string_literal: true

module Organizations
  module Billing
    # Enriches upcoming due dates with locked invoice data vs live PEPM preview / incomplete QBR.
    class PeriodViews
      View = Struct.new(
        :due_on,
        :calculation_on,
        :locked?,
        :pepm,
        :amount_due,
        :prior_pepm,
        :value_delivered_total,
        :teammate_count,
        :incomplete?,
        :value_analysis,
        keyword_init: true
      )

      def self.call(
        organization:,
        cadence:,
        live_pepm:,
        live_metrics:,
        months_in_period:,
        count: 3,
        first_due_on: nil,
        from: Date.current
      )
        new(
          organization: organization,
          cadence: cadence,
          live_pepm: live_pepm,
          live_metrics: live_metrics,
          months_in_period: months_in_period,
          count: count,
          first_due_on: first_due_on,
          from: from
        ).call
      end

      def initialize(
        organization:,
        cadence:,
        live_pepm:,
        live_metrics:,
        months_in_period:,
        count: 3,
        first_due_on: nil,
        from: Date.current
      )
        @organization = organization
        @cadence = cadence
        @live_pepm = live_pepm
        @live_metrics = live_metrics
        @months_in_period = months_in_period
        @count = count
        @first_due_on = first_due_on
        @from = from.to_date
      end

      def call
        periods = UpcomingPeriods.call(
          cadence: @cadence,
          count: @count,
          from: @from,
          first_due_on: @first_due_on
        )
        invoices_by_due = @organization.billing_invoices.where(due_on: periods.map(&:due_on)).index_by(&:due_on)
        prior_by_due = prior_pepms_before(periods.map(&:due_on))
        live_teammate_count = @live_metrics[:teammate_count].to_i
        live_value = @live_metrics[:total_value].to_f
        live_amount = AmountDue.call(
          pepm: @live_pepm.to_f,
          teammate_count: live_teammate_count,
          value_delivered: live_value,
          months: @months_in_period
        )

        periods.each_with_index.map do |period, index|
          invoice = invoices_by_due[period.due_on]
          locked = invoice.present?
          incomplete = !locked
          include_analysis = locked || (incomplete && index.zero?)
          View.new(
            due_on: period.due_on,
            calculation_on: period.calculation_on,
            locked?: locked,
            pepm: locked ? invoice.pepm.to_f : @live_pepm,
            amount_due: locked ? invoice.amount_due.to_f : live_amount,
            prior_pepm: prior_by_due[period.due_on],
            value_delivered_total: locked ? invoice.value_delivered_total&.to_f : live_value,
            teammate_count: locked ? invoice.teammate_count : live_teammate_count,
            incomplete?: incomplete,
            value_analysis: include_analysis ? ValueAnalysisTable.call(
              organization: @organization,
              cadence: @cadence,
              period_due_on: period.due_on
            ) : nil
          )
        end
      end

      private

      def prior_pepms_before(due_dates)
        return {} if due_dates.empty?

        priors = {}
        due_dates.each do |due_on|
          prior = @organization.billing_invoices
            .where("due_on < ?", due_on)
            .order(due_on: :desc)
            .limit(1)
            .pick(:pepm)
          priors[due_on] = prior&.to_f
        end
        priors
      end
    end
  end
end
