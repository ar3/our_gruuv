# frozen_string_literal: true

module Organizations
  module Billing
    class AmountDue
      def self.call(pepm:, teammate_count:, value_delivered:, months:)
        gross = pepm.to_f * teammate_count.to_i * months.to_i
        floored = [gross, value_delivered.to_f].min
        RoundDownToHalfDollar.call(floored)
      end
    end
  end
end
