# frozen_string_literal: true

module Goals
  # Age of a confidence check relative to a reference date (weekly OG3 rhythm).
  # Buckets: fresh ≤7d, aging 8–21d, stale >21d, never (no check).
  module ConfidenceAge
    FRESH_MAX_DAYS = 7
    AGING_MAX_DAYS = 21

    module_function

    def days_old(check_in, as_of: Date.current)
      return nil unless check_in&.check_in_week_start

      (as_of - check_in.check_in_week_start).to_i
    end

    def bucket(check_in, as_of: Date.current)
      days = days_old(check_in, as_of: as_of)
      return :never if days.nil?

      if days <= FRESH_MAX_DAYS
        :fresh
      elsif days <= AGING_MAX_DAYS
        :aging
      else
        :stale
      end
    end

    def stale?(check_in, as_of: Date.current)
      bucket(check_in, as_of: as_of) == :stale
    end

    def age_label(check_in, as_of: Date.current)
      days = days_old(check_in, as_of: as_of)
      return "never" if days.nil?

      if days < 7
        "#{days}d"
      else
        weeks = (days / 7.0).round
        "#{weeks}w"
      end
    end
  end
end
