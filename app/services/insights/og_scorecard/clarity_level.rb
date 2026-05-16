# frozen_string_literal: true

module Insights
  module OgScorecard
    module ClarityLevel
      module_function

      def from_finalized_at(finalized_at, reference_time:)
        return :obscured if finalized_at.blank?

        days = (reference_time.to_date - finalized_at.to_date).to_i

        if days <= CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS
          :crystal_clear
        elsif days <= CheckInBehavior::CLARITY_CLEAR_DAYS
          :clear
        elsif days <= CheckInBehavior::CLARITY_BLURRED_DAYS
          :blurred
        else
          :obscured
        end
      end

      def rollup_bucket(levels)
        symbols = levels.map(&:to_sym)
        return :clear if symbols.empty?

        return :obscured if symbols.include?(:obscured)
        return :blurred if symbols.include?(:blurred)

        :clear
      end
    end
  end
end
