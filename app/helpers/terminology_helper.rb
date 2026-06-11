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

  def clarity_hub_five_ways_intro_label(teammate_name:)
    terminology(:clarity_hub_five_ways_intro, teammate_name: teammate_name)
  end

  def clarity_hub_see_up_next_description_label
    terminology(:clarity_hub_see_up_next_description)
  end

  def clarity_hub_see_up_next_link_label(employee_name:, manager_name:)
    terminology(:clarity_hub_see_up_next_link, employee_name: employee_name, manager_name: manager_name)
  end

  def clarity_hub_see_full_queue_and_why_label
    terminology(:clarity_hub_see_full_queue_and_why)
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

  def set_day_to_day_assignments_label
    terminology(:set_day_to_day_assignments)
  end

  def set_day_to_day_assignments_title
    terminology(:set_day_to_day_assignments_title)
  end

  def set_day_to_day_assignments_subtitle
    terminology(:set_day_to_day_assignments_subtitle)
  end

  def set_assignments_view_label
    terminology(:set_assignments_view)
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

  def clarity_check_ins_awaiting_acknowledgement_label
    terminology(:clarity_check_ins_awaiting_acknowledgement)
  end

  def clarity_check_ins_awaiting_acknowledgement_description
    terminology(:clarity_check_ins_awaiting_acknowledgement_description)
  end

  def clarity_check_ins_awaiting_acknowledgement_summary(count:)
    terminology(:clarity_check_ins_awaiting_acknowledgement_summary, count: count)
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

  def insights_clarity_check_ins_health_label
    terminology(:insights_clarity_check_ins_health)
  end

  def review_finalize_clarity_check_ins_together_label
    terminology(:review_finalize_clarity_check_ins_together)
  end

  def switch_teammate_bulk_clarity_check_ins_label
    terminology(:switch_teammate_bulk_clarity_check_ins)
  end

  def back_to_one_by_one_clarity_check_in_label
    terminology(:back_to_one_by_one_clarity_check_in)
  end

  def clarity_check_in_statuses_title_label
    terminology(:clarity_check_in_statuses_title)
  end

  def review_most_recent_single_item_hint
    terminology(:review_most_recent_single_item_hint)
  end

  def go_to_bulk_clarity_check_in_page_label
    terminology(:go_to_bulk_clarity_check_in_page)
  end

  def bulk_page_clarity_check_in_hint
    terminology(:bulk_page_clarity_check_in_hint)
  end

  def bulk_page_intro
    terminology(:bulk_page_intro)
  end

  def go_to_clarity_check_in_status_page_label
    terminology(:go_to_clarity_check_in_status_page)
  end

  def bulk_status_page_table_hint
    terminology(:bulk_status_page_table_hint)
  end

  def update_and_go_to_bulk_clarity_check_in_label
    terminology(:update_and_go_to_bulk_clarity_check_in)
  end

  def update_and_go_to_review_clarity_check_ins_label
    terminology(:update_and_go_to_review_clarity_check_ins)
  end

  def one_by_one_clarity_check_in_on_name_label(name:)
    terminology(:one_by_one_clarity_check_in_on_name, name: name)
  end

  def finalize_clarity_check_ins_confirm_message
    terminology(:finalize_clarity_check_ins_confirm)
  end

  def close_selected_clarity_check_ins_label
    terminology(:close_selected_clarity_check_ins)
  end

  def manager_will_finalize_clarity_check_ins_label
    terminology(:manager_will_finalize_clarity_check_ins)
  end

  def no_clarity_check_ins_ready_for_finalization_label
    terminology(:no_clarity_check_ins_ready_for_finalization)
  end

  def finalize_clarity_check_ins_for_person_label(name:)
    terminology(:finalize_clarity_check_ins_for_person, name: name)
  end

  def finalize_clarity_check_ins_breadcrumb_label
    terminology(:finalize_clarity_check_ins_breadcrumb)
  end

  def clarity_check_ins_awaiting_input_description
    terminology(:clarity_check_ins_awaiting_input_description)
  end

  def clarity_check_ins_awaiting_input_summary(count:)
    terminology(:clarity_check_ins_awaiting_input_summary, count: count)
  end

  def clarity_check_in_acknowledgement_nudges_label
    terminology(:clarity_check_in_acknowledgement_nudges)
  end

  def unacknowledged_finalized_clarity_check_ins_help
    terminology(:unacknowledged_finalized_clarity_check_ins_help)
  end

  def same_scopes_as_clarity_check_ins_health_label
    terminology(:same_scopes_as_clarity_check_ins_health)
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

  def save_all_confidence_checks_label
    terminology(:save_all_confidence_checks)
  end

  def weekly_goal_confidence_check_in_bulk_label
    terminology(:weekly_goal_confidence_check_in_bulk)
  end

  def weekly_goal_confidence_check_in_bulk_description
    terminology(:weekly_goal_confidence_check_in_bulk_description)
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

  def checking_in_starts_goal_label
    terminology(:checking_in_starts_goal)
  end

  def goal_completed_confidence_checks_readonly_label
    terminology(:goal_completed_confidence_checks_readonly)
  end

  def start_goal_to_add_confidence_checks_label
    terminology(:start_goal_to_add_confidence_checks)
  end

  def anyone_can_submit_confidence_checks_label
    terminology(:anyone_can_submit_confidence_checks)
  end

  def creator_owner_confidence_check_permission_label
    terminology(:creator_owner_confidence_check_permission)
  end

  def goal_must_be_started_for_confidence_check_mode_label
    terminology(:goal_must_be_started_for_confidence_check_mode)
  end

  def record_final_confidence_check_and_learnings_label
    terminology(:record_final_confidence_check_and_learnings)
  end

  def no_confidence_checks_recorded_label
    terminology(:no_confidence_checks_recorded)
  end

  def final_confidence_check_reason_hint_label
    terminology(:final_confidence_check_reason_hint)
  end

  def hierarchical_collapsible_with_confidence_checks_label
    terminology(:hierarchical_collapsible_with_confidence_checks)
  end

  def progress_chart_confidence_checks_help_label
    terminology(:progress_chart_confidence_checks_help)
  end

  def observations_confidence_checks_tooltip_label
    terminology(:observations_confidence_checks_tooltip)
  end

  def confidence_check_saved_successfully_label
    terminology(:confidence_check_saved_successfully)
  end

  def some_confidence_checks_failed_save_label(success_count:, failure_count:)
    terminology(:some_confidence_checks_failed_save, success_count: success_count, failure_count: failure_count)
  end

  def successfully_saved_confidence_checks_count_label(count:)
    terminology(:successfully_saved_confidence_checks_count, count: count)
  end

  def add_confidence_checks_on_active_goals_label(count:)
    terminology(:add_confidence_checks_on_active_goals, count: count)
  end

  def goals_needing_confidence_check_summary(count:)
    terminology(:goals_needing_confidence_check_summary, count: count)
  end

  def no_confidence_check_yet_label
    terminology(:no_confidence_check_yet)
  end

  def only_creator_owner_can_add_confidence_checks_label
    terminology(:only_creator_owner_can_add_confidence_checks)
  end

  def no_permission_add_confidence_checks_label
    terminology(:no_permission_add_confidence_checks)
  end

  def edit_all_goals_confidence_checks_label
    terminology(:edit_all_goals_confidence_checks)
  end

  def goal_confidence_checks_description
    terminology(:goal_confidence_checks_description)
  end

  def with_confidence_check_in_past_two_weeks
    terminology(:with_confidence_check_in_past_two_weeks)
  end

  # --- 1:1 (avoid "1:1 check-in") ---

  def weekly_1_1_label
    terminology(:weekly_1_1)
  end

  def weekly_1_1_intro_label
    terminology(:weekly_1_1_intro)
  end

  def due_now_no_finalized_clarity_check_in_label
    terminology(:due_now_no_finalized_clarity_check_in)
  end

  def no_clarity_check_in_schedule_data_label
    terminology(:no_clarity_check_in_schedule_data)
  end

  def one_on_one_hub_label
    terminology(:one_on_one_hub)
  end

  def clarity_check_in_history_label
    terminology(:clarity_check_in_history)
  end

  def acknowledge_finalized_clarity_check_in_label
    terminology(:acknowledge_finalized_clarity_check_in)
  end

  def dashboard_clarity_descriptions
    [
      terminology(:dashboard_clarity_description_1),
      terminology(:dashboard_clarity_description_2),
      terminology(:dashboard_clarity_description_3)
    ]
  end

  def about_me_start_here_intro_label
    terminology(:about_me_start_here_intro)
  end

  def my_goals_recent_confidence_check_label(count:)
    terminology(:my_goals_recent_confidence_check, count: count)
  end

  def my_goals_stale_confidence_check_label(count:)
    terminology(:my_goals_stale_confidence_check, count: count)
  end

  def no_completed_clarity_check_in_yet_label
    terminology(:no_completed_clarity_check_in_yet)
  end

  def no_clarity_check_in_health_data_label
    terminology(:no_clarity_check_in_health_data)
  end

  def no_clarity_check_ins_awaiting_your_input_label
    terminology(:no_clarity_check_ins_awaiting_your_input)
  end

  def all_clarity_check_ins_fresh_label
    terminology(:all_clarity_check_ins_fresh)
  end

  def all_clarity_check_ins_fresh_sub_label
    terminology(:all_clarity_check_ins_fresh_sub)
  end

  def dashboard_clarity_check_in_on_assignments_label(count:)
    key = count == 1 ? :dashboard_clarity_check_in_on_assignments : :dashboard_clarity_check_in_on_assignments_other
    terminology(key, count: count)
  end

  def go_add_confidence_checks_on_goals_label(name:, count:)
    key = count == 1 ? :go_add_confidence_checks_on_goals : :go_add_confidence_checks_on_goals_other
    terminology(key, name: name, count: count)
  end

  def position_check_in_from_clarity_hub_label
    terminology(:position_check_in_from_clarity_hub)
  end
end
