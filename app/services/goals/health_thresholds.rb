# frozen_string_literal: true

module Goals
  module HealthThresholds
    COMPLETED_RECENTLY_DAYS = 90
    CHECK_IN_RECENCY_DAYS = 14
    DANGER_PERCENT_ALERT_THRESHOLD = 20.0

    module_function

    def completed_recently_cutoff
      COMPLETED_RECENTLY_DAYS.days.ago
    end

    def check_in_recency_cutoff_week_start
      (Date.current - CHECK_IN_RECENCY_DAYS.days).beginning_of_week(:monday)
    end
  end
end
