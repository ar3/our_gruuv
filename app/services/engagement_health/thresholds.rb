# frozen_string_literal: true

module EngagementHealth
  # The threshold table. OGOs and goal confidence use a 30/90-day model;
  # required clarity check-ins use a stricter 60/90-day model because they
  # are required. Required clarity until-dates / Grey Grace are computed in
  # RequiredClarityWindows (tenure chain, teammate override, last finalize).

  module Thresholds
    OGO_HEALTHY_WITHIN_DAYS = 30
    OGO_NEEDS_ATTENTION_AT_DAYS = 90

    GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS = 30
    GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS = 90

    REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS = 60
    REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS = 90

    # UI-only: collapse the check-in form behind "check in early" when the
    # latest finalize is this fresh. Not an Engagement Health status band.
    CHECK_IN_EARLY_WITHIN_DAYS = 30

    # Assignments only: tenure-based Grey Grace window length (same as healthy).
    NEW_ASSIGNMENT_GRACE_WITHIN_DAYS = REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS


    # Completed goals stay in the goal-confidence rollup for this long after
    # completion, then drop out.
    COMPLETED_GOAL_WINDOW_DAYS = 90

    module_function

    def days_since(time, reference_time: Time.current)
      return nil if time.blank?

      days = (reference_time.to_date - time.to_date).to_i
      days.negative? ? nil : days
    end

    # MECE by construction: Needs Attention when never or >= needs_attention_at
    # days, Healthy when <= healthy_within days, Warning = everything else
    # ("not Healthy and not Needs Attention"), so there are no boundary gaps.
    def status_for_last_event(last_event_at, healthy_within:, needs_attention_at:, reference_time: Time.current)
      days = days_since(last_event_at, reference_time: reference_time)
      return NEEDS_ATTENTION if days.nil? || days >= needs_attention_at
      return HEALTHY if days <= healthy_within

      WARNING
    end
  end
end
