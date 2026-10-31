# frozen_string_literal: true

module EngagementHealth
  # The threshold table. OGOs and goal confidence use a 30/90-day model;
  # required clarity check-ins use a stricter 60/90-day model because they
  # are required (orgs may override the Required Clarity pair via company
  # preferences). Required clarity until-dates / Grey Grace are computed in
  # RequiredClarityWindows (tenure chain, teammate override, last finalize).

  module Thresholds
    OGO_HEALTHY_WITHIN_DAYS = 30
    OGO_NEEDS_ATTENTION_AT_DAYS = 90

    GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS = 30
    GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS = 90

    # Defaults when the company has no override in company_label_preferences.
    REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS = 60
    REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS = 90

    # UI-only: collapse the check-in form behind "check in early" when the
    # latest finalize is this fresh. Not an Engagement Health status band and
    # not org-configurable (fixed floor for Healthy validation).
    CHECK_IN_EARLY_WITHIN_DAYS = 30

    # Preference keys on CompanyLabelPreference (same hot path as prompt labels).
    REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY = "required_clarity_healthy_within_days"
    REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY = "required_clarity_needs_attention_at_days"

    # Assignments only: tenure-based Grey Grace window length (tracks Healthy).
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

    # Org-aware Required Clarity Healthy window (default 60).
    def required_clarity_healthy_within_days(organization = nil)
      read_required_clarity_day_pref(organization, REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY) ||
        REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS
    end

    # Org-aware Required Clarity Needs Attention day (default 90).
    def required_clarity_needs_attention_at_days(organization = nil)
      read_required_clarity_day_pref(organization, REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY) ||
        REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
    end

    # Grey Grace tenure window tracks org Healthy.
    def new_assignment_grace_within_days(organization = nil)
      required_clarity_healthy_within_days(organization)
    end

    # Prefer values baked into EH cache inputs; else org methods / defaults.
    def required_clarity_healthy_within_days_from(inputs: nil, organization: nil)
      from_inputs = parse_positive_int(inputs.is_a?(Hash) ? inputs["healthy_within_days"] : nil)
      from_inputs || required_clarity_healthy_within_days(organization)
    end

    def required_clarity_needs_attention_at_days_from(inputs: nil, organization: nil)
      from_inputs = parse_positive_int(inputs.is_a?(Hash) ? inputs["needs_attention_at_days"] : nil)
      from_inputs || required_clarity_needs_attention_at_days(organization)
    end

    def read_required_clarity_day_pref(organization, key)
      company = organization&.root_company || organization
      return nil unless company.respond_to?(:company_label_preferences)

      prefs = company.company_label_preferences
      preference = if prefs.loaded?
        prefs.find { |row| row.label_key == key.to_s }
      else
        prefs.find_by(label_key: key.to_s)
      end
      parse_positive_int(preference&.label_value)
    end
    private_class_method :read_required_clarity_day_pref

    def parse_positive_int(value)
      return nil if value.blank?

      int = Integer(value)
      int.positive? ? int : nil
    rescue ArgumentError, TypeError
      nil
    end
    private_class_method :parse_positive_int
  end
end
