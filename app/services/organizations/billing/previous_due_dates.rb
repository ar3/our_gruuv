# frozen_string_literal: true

module Organizations
  module Billing
    class PreviousDueDates
      QUARTERLY_MONTHS = NextDueDate::QUARTERLY_MONTHS
      SEMIANNUAL_MONTHS = NextDueDate::SEMIANNUAL_MONTHS

      def self.call(cadence:, before:, count: 6)
        new(cadence: cadence, before: before, count: count).call
      end

      def initialize(cadence:, before:, count: 6)
        @cadence = cadence
        @before = before.to_date
        @count = count
      end

      def call
        dates = []
        cursor = @before
        @count.times do
          prev = previous_one(cursor)
          break if prev.nil?

          dates << prev
          cursor = prev
        end
        dates
      end

      private

      def previous_one(before)
        case @cadence
        when "monthly"
          (before - 1.day).beginning_of_month
        when "quarterly"
          previous_first_of_months(QUARTERLY_MONTHS, before)
        when "semiannual"
          previous_first_of_months(SEMIANNUAL_MONTHS, before)
        else
          (before - 1.day).beginning_of_month
        end
      end

      def previous_first_of_months(months, before)
        year = before.year
        candidates = months.flat_map { |month| [Date.new(year, month, 1), Date.new(year - 1, month, 1)] }
        candidates.select { |date| date < before }.max
      end
    end
  end
end
