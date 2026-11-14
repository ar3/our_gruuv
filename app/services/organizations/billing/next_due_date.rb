# frozen_string_literal: true

module Organizations
  module Billing
    class NextDueDate
      QUARTERLY_MONTHS = [1, 4, 7, 10].freeze
      SEMIANNUAL_MONTHS = [1, 7].freeze

      def self.call(cadence:, from: Date.current)
        new(cadence: cadence, from: from).call
      end

      def initialize(cadence:, from: Date.current)
        @cadence = cadence
        @from = from.to_date
      end

      def call
        case @cadence
        when "monthly"
          next_month_first
        when "quarterly"
          next_first_of_months(QUARTERLY_MONTHS)
        when "semiannual"
          next_first_of_months(SEMIANNUAL_MONTHS)
        else
          next_month_first
        end
      end

      private

      def next_month_first
        return @from if @from.day == 1

        @from.next_month.beginning_of_month
      end

      def next_first_of_months(months)
        year = @from.year
        candidates = months.map { |month| Date.new(year, month, 1) }
        candidates << Date.new(year + 1, months.first, 1)
        candidates.find { |date| date >= @from } || candidates.last
      end
    end
  end
end
