# frozen_string_literal: true

module Organizations
  module Billing
    # Charges round down to the nearest $0.50. Below $0.50 → $0.
    class RoundDownToHalfDollar
      HALF_DOLLAR = 0.5

      def self.call(amount)
        return nil if amount.nil?

        value = amount.to_f
        return 0.0 if value < HALF_DOLLAR

        ((value / HALF_DOLLAR).floor * HALF_DOLLAR).round(2)
      end
    end
  end
end
