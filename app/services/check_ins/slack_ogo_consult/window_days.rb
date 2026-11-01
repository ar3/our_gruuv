# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Maps a check-in "since" bound to a Slack search window_days value.
    # First check-in (no since) → 30 days. Otherwise snap up to an allowed bucket
    # so the Slack fetch covers at least the check-in window.
    class WindowDays
      def self.call(since:, until_time: Time.current)
        new(since: since, until_time: until_time).call
      end

      def initialize(since:, until_time: Time.current)
        @since = since
        @until_time = until_time || Time.current
      end

      def call
        return 30 if @since.blank?

        needed = [((@until_time - @since) / 1.day).ceil, 1].max
        PossibleObservationSlackSearch::ALLOWED_WINDOW_DAYS.find { |days| days >= needed } ||
          PossibleObservationSlackSearch::ALLOWED_WINDOW_DAYS.last
      end
    end
  end
end
