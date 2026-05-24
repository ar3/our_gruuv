# frozen_string_literal: true

# Central glossary for clarity check-ins (standings) vs confidence checks (goals).
# Prefer these helpers over hardcoded strings in views and user-facing messages.
module TerminologyHelper
  def terminology(key, **options)
    t("terminology.#{key}", **options)
  end

  # --- Clarity Check-Ins hub / clarity check-ins (position, assignment, aspiration) ---

  def clarity_hub_label
    terminology(:clarity_hub)
  end

  def clarity_hub_active_label
    terminology(:clarity_hub_active)
  end

  def clarity_hub_description
    terminology(:clarity_hub_description)
  end

  def switch_teammate_for_clarity_hub_label
    terminology(:switch_teammate_for_clarity_hub)
  end

  def view_audit_clarity_check_in_acknowledgements_label(count:)
    terminology(:view_audit_clarity_check_in_acknowledgements, count: count)
  end

  def finalize_clarity_check_ins_both_sides_label
    terminology(:finalize_clarity_check_ins_both_sides)
  end

  def view_latest_clarity_check_ins_description
    terminology(:view_latest_clarity_check_ins_description)
  end

  def choose_any_for_clarity_check_in_label
    terminology(:choose_any_for_clarity_check_in)
  end

  def early_clarity_check_in_on_label(label:)
    terminology(:early_clarity_check_in_on, label: label)
  end

  def clarity_check_in_features_tooltip
    terminology(:clarity_check_in_features_tooltip)
  end

  def clarity_check_in_label
    terminology(:clarity_check_in)
  end

  def clarity_check_ins_label
    terminology(:clarity_check_ins)
  end

  def bulk_clarity_check_in_label
    terminology(:bulk_clarity_check_in)
  end

  def clarity_check_in_one_at_a_time_label
    terminology(:clarity_check_in_one_at_a_time)
  end

  def early_clarity_check_in_one_thing_label
    terminology(:early_clarity_check_in_one_thing)
  end

  def view_latest_clarity_check_ins_label
    terminology(:view_latest_clarity_check_ins)
  end

  def review_clarity_check_ins_together_label(count:)
    terminology(:review_clarity_check_ins_together, count: count)
  end

  def view_clarity_hub_label
    terminology(:view_clarity_hub)
  end

  def go_to_clarity_hub_label
    terminology(:go_to_clarity_hub)
  end

  def clarity_check_in_history_label
    terminology(:clarity_check_in_history)
  end

  def finalize_selected_clarity_check_ins_label
    terminology(:finalize_selected_clarity_check_ins)
  end

  def clarity_check_ins_awaiting_your_input_label
    terminology(:clarity_check_ins_awaiting_your_input)
  end

  def review_clarity_check_ins_label
    terminology(:review_clarity_check_ins)
  end

  def save_all_proceed_review_clarity_check_ins_label
    terminology(:save_all_proceed_review_clarity_check_ins)
  end

  def one_by_one_clarity_check_in_label
    terminology(:one_by_one_clarity_check_in)
  end

  def upcoming_clarity_check_ins_label
    terminology(:upcoming_clarity_check_ins)
  end

  def clarity_check_in_statuses_label
    terminology(:clarity_check_in_statuses)
  end

  def insights_clarity_check_ins_progress_label
    terminology(:insights_clarity_check_ins_progress)
  end

  # --- Confidence checks (goals) ---

  def confidence_check_label
    terminology(:confidence_check)
  end

  def confidence_checks_label
    terminology(:confidence_checks)
  end

  def confidence_check_mode_label
    terminology(:confidence_check_mode)
  end

  def confidence_check_mode_active_label
    terminology(:confidence_check_mode_active)
  end

  def confidence_check_history_label
    terminology(:confidence_check_history)
  end

  def current_week_confidence_check_label
    terminology(:current_week_confidence_check)
  end

  def save_confidence_check_label
    terminology(:save_confidence_check)
  end

  def current_confidence_check_week_label
    terminology(:current_confidence_check_week)
  end

  def goal_confidence_checks_label
    terminology(:goal_confidence_checks)
  end

  def goals_needing_confidence_check_label
    terminology(:goals_needing_confidence_check)
  end

  def new_confidence_check_needed_label
    terminology(:new_confidence_check_needed)
  end

  def no_confidence_checks_yet_label
    terminology(:no_confidence_checks_yet)
  end

  def last_confidence_check_label
    terminology(:last_confidence_check)
  end

  def need_confidence_check_label
    terminology(:need_confidence_check)
  end

  def weekly_confidence_checks_label
    terminology(:weekly_confidence_checks)
  end

  def confidence_checks_on_your_goals_label
    terminology(:confidence_checks_on_your_goals)
  end

  def failed_to_save_confidence_check_label
    terminology(:failed_to_save_confidence_check)
  end

  def failed_to_save_confidence_checks_label
    terminology(:failed_to_save_confidence_checks)
  end

  def goal_has_no_confidence_checks_label
    terminology(:goal_has_no_confidence_checks)
  end

  def last_confidence_check_ago_label(time:)
    terminology(:last_confidence_check_ago, time: time)
  end

  def who_can_edit_confidence_checks_label
    terminology(:who_can_edit_confidence_checks)
  end

  def observations_and_goal_confidence_checks_label
    terminology(:observations_and_goal_confidence_checks)
  end

  def weekly_confidence_check_tooltip_label
    terminology(:weekly_confidence_check_tooltip)
  end

  # --- 1:1 (avoid "1:1 check-in") ---

  def weekly_1_1_label
    terminology(:weekly_1_1)
  end

  def one_on_one_hub_label
    terminology(:one_on_one_hub)
  end
end
