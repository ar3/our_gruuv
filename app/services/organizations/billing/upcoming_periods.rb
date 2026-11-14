# frozen_string_literal: true

module Organizations
  module Billing
    class UpcomingPeriods
      Period = Struct.new(
        :due_on,
        :calculation_on,
        :calculation_passed?,
        keyword_init: true
      )

      def self.call(cadence:, count: 3, from: Date.current, first_due_on: nil)
        new(cadence: cadence, count: count, from: from, first_due_on: first_due_on).call
      end

      def initialize(cadence:, count: 3, from: Date.current, first_due_on: nil)
        @cadence = cadence
        @count = count
        @from = from.to_date
        @first_due_on = first_due_on&.to_date
      end

      def call
        due_dates.map do |due_on|
          calculation_on = due_on - 1.week
          Period.new(
            due_on: due_on,
            calculation_on: calculation_on,
            calculation_passed?: calculation_on <= @from
          )
        end
      end

      private

      def due_dates
        dates = []
        cursor = @from
        @count.times do |index|
          due =
            if index.zero? && @first_due_on.present? && @first_due_on >= @from
              @first_due_on
            else
              NextDueDate.call(cadence: @cadence, from: cursor)
            end
          dates << due
          cursor = due + 1.day
        end
        dates
      end
    end
  end
end
