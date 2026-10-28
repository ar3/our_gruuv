# frozen_string_literal: true

module EngagementHealth
  # Single place that turns last finalize / tenure / teammate override into
  # until-dates and Healthy / Warning (incl. Grey Grace) / Needs Attention.
  # Threshold day counts come from Thresholds so Phase 3 can swap the source.
  module RequiredClarityWindows
    module_function

    # Returns a hash of dates (Date or nil) plus status and grace flag.
    # Dates are calendar dates in the reference timezone.
    #
    # Inclusive ends: healthy_until_at / grace_until_at / warning_until_at are
    # the last day in that band. needs_attention_at is the first Needs Attention day.
    def compute(
      last_finalized_at:,
      tenure_chain_started_at:,
      teammate_grace_until:,
      healthy_within: Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS,
      needs_attention_at_days: Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS,
      reference_time: Time.current,
      # Assignments with no consecutive >0% tenure: Grey Grace until energy is assigned.
      indefinite_tenure_grace: false
    )
      ref = reference_time.to_date
      tenure_grace_until = tenure_grace_until_date(tenure_chain_started_at, healthy_within)
      override = teammate_grace_until&.to_date
      grace_until_at = [override, tenure_grace_until].compact.max

      healthy_until_at = nil
      warning_until_at = nil
      needs_attention_at = nil

      if last_finalized_at.present?
        finalized_on = last_finalized_at.to_date
        healthy_until_at = finalized_on + healthy_within.days
        needs_attention_at = finalized_on + needs_attention_at_days.days
        warning_until_at = needs_attention_at - 1.day
      elsif grace_until_at.present?
        # Never finalized: Grey Grace through grace_until, then Needs Attention.
        warning_until_at = grace_until_at
        needs_attention_at = grace_until_at + 1.day
      end

      status, in_grace = status_and_grace(
        reference_date: ref,
        healthy_until_at: healthy_until_at,
        grace_until_at: grace_until_at,
        needs_attention_at: needs_attention_at
      )

      if indefinite_tenure_grace && !(healthy_until_at.present? && ref <= healthy_until_at)
        status = WARNING
        in_grace = true
        # No tenure clock → no Needs Attention date until >0% energy exists.
        needs_attention_at = nil
        warning_until_at = grace_until_at
      end

      {
        grace_until_at: grace_until_at,
        healthy_until_at: healthy_until_at,
        warning_until_at: warning_until_at,
        needs_attention_at: needs_attention_at,
        tenure_grace_until_at: tenure_grace_until,
        teammate_grace_until_at: override,
        status: status,
        clarity_check_in_grace: in_grace,
        indefinite_tenure_grace: indefinite_tenure_grace && in_grace
      }
    end


    def tenure_grace_until_date(tenure_chain_started_at, healthy_within)
      return nil if tenure_chain_started_at.blank?

      # Match prior days_since < healthy_within: last inclusive grace day is start + (N - 1).
      tenure_chain_started_at.to_date + (healthy_within - 1).days
    end

    def status_and_grace(reference_date:, healthy_until_at:, grace_until_at:, needs_attention_at:)
      if healthy_until_at.present? && reference_date <= healthy_until_at
        return [HEALTHY, false]
      end

      if grace_until_at.present? && reference_date <= grace_until_at
        return [WARNING, true]
      end

      if needs_attention_at.blank? || reference_date >= needs_attention_at
        return [NEEDS_ATTENTION, false]
      end

      [WARNING, false]
    end
  end
end
