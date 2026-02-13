# frozen_string_literal: true

module Goals
  # Calculates confidence thresholds for goal progress status (ahead / on schedule / behind).
  # Requires: most_likely_target_date, started_at, progress_check_date.
  # Optional: initial_confidence (default :stretch), earliest_target_date (defaults to most_likely), latest_target_date (defaults to most_likely).
  class GoalProgressStatusConfidenceRangeCalculator
    INITIAL_CONFIDENCE_CONFIG = {
      commit: { step: 0.2, start: 80 },
      stretch: { step: 0.5, start: 50 },
      transform: { step: 0.8, start: 20 }
    }.freeze

    def self.call(...) = new(...).call

    def initialize(
      initial_confidence: nil,
      earliest_target_date: nil,
      latest_target_date: nil,
      most_likely_target_date:,
      started_at:,
      progress_check_date:
    )
      @initial_confidence = (initial_confidence || :stretch).to_sym
      @earliest_target_date = earliest_target_date
      @latest_target_date = latest_target_date
      @most_likely_target_date = most_likely_target_date
      @started_at = started_at
      @progress_check_date = progress_check_date
    end

    def call
      return nil if @most_likely_target_date.nil? || @started_at.nil? || @progress_check_date.nil?

      config = INITIAL_CONFIDENCE_CONFIG[@initial_confidence]
      config ||= INITIAL_CONFIDENCE_CONFIG[:stretch]

      earliest = @earliest_target_date || @most_likely_target_date
      latest = @latest_target_date || @most_likely_target_date

      start_date = @started_at.to_date
      check_date = @progress_check_date.respond_to?(:to_date) ? @progress_check_date.to_date : @progress_check_date
      most_likely = @most_likely_target_date.respond_to?(:to_date) ? @most_likely_target_date.to_date : @most_likely_target_date
      earliest_d = earliest.respond_to?(:to_date) ? earliest.to_date : earliest
      latest_d = latest.respond_to?(:to_date) ? latest.to_date : latest

      time_lapsed_earliest = time_lapsed_percent(start_date, check_date, earliest_d)
      time_lapsed_most_likely = time_lapsed_percent(start_date, check_date, most_likely)
      time_lapsed_latest = time_lapsed_percent(start_date, check_date, latest_d)

      earliest_threshold = threshold(config, time_lapsed_earliest)
      most_likely_threshold = threshold(config, time_lapsed_most_likely)
      latest_threshold = threshold(config, time_lapsed_latest)

      {
        behind_schedule_if_confidence_below: latest_threshold,
        ahead_of_schedule_if_confidence_above: earliest_threshold,
        on_schedule_if_confidence_above: most_likely_threshold
      }
    end

    private

    def time_lapsed_percent(started_at_date, progress_check_date, target_date)
      return 0 if target_date <= started_at_date

      elapsed = (progress_check_date - started_at_date).to_f
      total = (target_date - started_at_date).to_f
      return 0 if total <= 0

      ((elapsed / total) * 100)
    end

    def threshold(config, time_lapsed_percent)
      value = config[:start] + (time_lapsed_percent * config[:step])
      [value, 100].min
    end
  end
end
