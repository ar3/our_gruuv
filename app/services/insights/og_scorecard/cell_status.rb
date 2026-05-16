# frozen_string_literal: true

module Insights
  module OgScorecard
    # Maps a weekly metric value to :success, :warning, :danger, or :neutral using configured thresholds.
    class CellStatus
      STATUSES = %i[success warning danger neutral].freeze

      def self.for(value:, yellow:, green:, direction:, mode:, active_teammate_count:)
        new(
          value: value,
          yellow: yellow,
          green: green,
          direction: direction,
          mode: mode,
          active_teammate_count: active_teammate_count
        ).call
      end

      def initialize(value:, yellow:, green:, direction:, mode:, active_teammate_count:)
        @value = value
        @yellow = yellow
        @green = green
        @direction = direction.to_sym
        @mode = mode.to_s
        @active_teammate_count = active_teammate_count
      end

      def call
        return :neutral unless configured?

        compare_value = comparison_value
        return :neutral if compare_value.nil?

        if direction == :less
          less_is_better_status(compare_value)
        else
          more_is_better_status(compare_value)
        end
      end

      private

      attr_reader :value, :yellow, :green, :direction, :mode, :active_teammate_count

      def configured?
        yellow.present? && green.present?
      end

      def comparison_value
        if mode == 'percent'
          return nil if active_teammate_count.to_i.zero?

          (value.to_f / active_teammate_count * 100.0)
        else
          value.to_f
        end
      end

      def more_is_better_status(v)
        y = yellow.to_f
        g = green.to_f
        return :success if v >= g
        return :warning if v >= y

        :danger
      end

      def less_is_better_status(v)
        y = yellow.to_f
        g = green.to_f
        return :success if v <= g
        return :warning if v <= y

        :danger
      end
    end
  end
end
