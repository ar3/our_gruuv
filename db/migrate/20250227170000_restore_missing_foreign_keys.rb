# frozen_string_literal: true

# Restore foreign keys that were lost when db:schema:load:queue was run with
# the wrong queue_schema.rb (full app schema). That command connected to the
# same DB and began dropping/recreating tables, then failed partway through
# add_foreign_key, leaving the DB without most FKs. This migration re-adds
# them. Uses if_not_exists: true so already-present FKs (e.g. abilities) are skipped.
class RestoreMissingForeignKeys < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key "abilities", "departments", if_not_exists: true
    add_foreign_key "abilities", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "abilities", "people", column: "created_by_id", if_not_exists: true
    add_foreign_key "abilities", "people", column: "updated_by_id", if_not_exists: true
    add_foreign_key "addresses", "people", if_not_exists: true
    add_foreign_key "aspiration_check_ins", "aspirations", if_not_exists: true
    add_foreign_key "aspiration_check_ins", "maap_snapshots", if_not_exists: true
    add_foreign_key "aspiration_check_ins", "teammates", if_not_exists: true
    add_foreign_key "aspirations", "departments", if_not_exists: true
    add_foreign_key "aspirations", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "assignment_abilities", "abilities", if_not_exists: true
    add_foreign_key "assignment_abilities", "assignments", if_not_exists: true
    add_foreign_key "assignment_check_ins", "assignments", if_not_exists: true
    add_foreign_key "assignment_check_ins", "maap_snapshots", if_not_exists: true
    add_foreign_key "assignment_check_ins", "teammates", if_not_exists: true
    add_foreign_key "assignment_flow_memberships", "assignment_flows", if_not_exists: true
    add_foreign_key "assignment_flow_memberships", "assignments", if_not_exists: true
    add_foreign_key "assignment_flow_memberships", "teammates", column: "added_by_id", if_not_exists: true
    add_foreign_key "assignment_flows", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "assignment_flows", "teammates", column: "created_by_id", if_not_exists: true
    add_foreign_key "assignment_flows", "teammates", column: "updated_by_id", if_not_exists: true
    add_foreign_key "assignment_outcomes", "assignments", if_not_exists: true
    add_foreign_key "assignment_supply_relationships", "assignments", column: "consumer_assignment_id", if_not_exists: true
    add_foreign_key "assignment_supply_relationships", "assignments", column: "supplier_assignment_id", if_not_exists: true
    add_foreign_key "assignment_tenures", "assignments", if_not_exists: true
    add_foreign_key "assignment_tenures", "teammates", if_not_exists: true
    add_foreign_key "assignments", "departments", if_not_exists: true
    add_foreign_key "assignments", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "bulk_downloads", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "bulk_downloads", "teammates", column: "downloaded_by_id", if_not_exists: true
    add_foreign_key "bulk_sync_events", "organizations", if_not_exists: true
    add_foreign_key "bulk_sync_events", "people", column: "creator_id", if_not_exists: true
    add_foreign_key "bulk_sync_events", "people", column: "initiator_id", if_not_exists: true
    add_foreign_key "comments", "organizations", if_not_exists: true
    add_foreign_key "comments", "people", column: "creator_id", if_not_exists: true
    add_foreign_key "company_label_preferences", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "departments", "departments", column: "parent_department_id", if_not_exists: true
    add_foreign_key "departments", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "employment_tenures", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "employment_tenures", "positions", if_not_exists: true
    add_foreign_key "employment_tenures", "seats", if_not_exists: true
    add_foreign_key "employment_tenures", "teammates", if_not_exists: true
    add_foreign_key "employment_tenures", "teammates", column: "manager_teammate_id", if_not_exists: true
    add_foreign_key "external_project_caches", "teammates", column: "last_synced_by_teammate_id", if_not_exists: true
    add_foreign_key "feedback_request_questions", "feedback_requests", if_not_exists: true
    add_foreign_key "feedback_request_responders", "feedback_requests", if_not_exists: true
    add_foreign_key "feedback_request_responders", "teammates", if_not_exists: true
    add_foreign_key "feedback_requests", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "feedback_requests", "teammates", column: "requestor_teammate_id", if_not_exists: true
    add_foreign_key "feedback_requests", "teammates", column: "subject_of_feedback_teammate_id", if_not_exists: true
    add_foreign_key "goal_check_ins", "goals", if_not_exists: true
    add_foreign_key "goal_check_ins", "people", column: "confidence_reporter_id", if_not_exists: true
    add_foreign_key "goal_links", "goals", column: "child_id", if_not_exists: true
    add_foreign_key "goal_links", "goals", column: "parent_id", if_not_exists: true
    add_foreign_key "goals", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "goals", "teammates", column: "creator_id", if_not_exists: true
    add_foreign_key "huddle_feedbacks", "huddles", if_not_exists: true
    add_foreign_key "huddle_feedbacks", "teammates", if_not_exists: true
    add_foreign_key "huddle_participants", "huddles", if_not_exists: true
    add_foreign_key "huddle_participants", "teammates", if_not_exists: true
    add_foreign_key "huddles", "teams", if_not_exists: true
    add_foreign_key "interest_submissions", "people", if_not_exists: true
    add_foreign_key "kudos_points_ledgers", "organizations", if_not_exists: true
    add_foreign_key "kudos_points_ledgers", "teammates", column: "company_teammate_id", if_not_exists: true
    add_foreign_key "kudos_redemptions", "kudos_rewards", if_not_exists: true
    add_foreign_key "kudos_redemptions", "organizations", if_not_exists: true
    add_foreign_key "kudos_redemptions", "teammates", column: "company_teammate_id", if_not_exists: true
    add_foreign_key "kudos_rewards", "organizations", if_not_exists: true
    add_foreign_key "kudos_transactions", "kudos_redemptions", if_not_exists: true
    add_foreign_key "kudos_transactions", "kudos_transactions", column: "triggering_transaction_id", if_not_exists: true
    add_foreign_key "kudos_transactions", "observable_moments", if_not_exists: true
    add_foreign_key "kudos_transactions", "observations", if_not_exists: true
    add_foreign_key "kudos_transactions", "organizations", if_not_exists: true
    add_foreign_key "kudos_transactions", "teammates", column: "company_teammate_banker_id", if_not_exists: true
    add_foreign_key "kudos_transactions", "teammates", column: "company_teammate_id", if_not_exists: true
    add_foreign_key "maap_snapshots", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "maap_snapshots", "teammates", column: "creator_company_teammate_id", if_not_exists: true
    add_foreign_key "maap_snapshots", "teammates", column: "employee_company_teammate_id", if_not_exists: true
    add_foreign_key "missing_resource_requests", "missing_resources", if_not_exists: true
    add_foreign_key "missing_resource_requests", "people", if_not_exists: true
    add_foreign_key "notifications", "notifications", column: "main_thread_id", if_not_exists: true
    add_foreign_key "notifications", "notifications", column: "original_message_id", if_not_exists: true
    add_foreign_key "observable_moments", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "observable_moments", "people", column: "created_by_id", if_not_exists: true
    add_foreign_key "observable_moments", "teammates", column: "primary_potential_observer_id", if_not_exists: true
    add_foreign_key "observable_moments", "teammates", column: "processed_by_teammate_id", if_not_exists: true
    add_foreign_key "observation_ratings", "observations", if_not_exists: true
    add_foreign_key "observations", "feedback_request_questions", if_not_exists: true
    add_foreign_key "observations", "observable_moments", if_not_exists: true
    add_foreign_key "observations", "observation_triggers", if_not_exists: true
    add_foreign_key "observations", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "observations", "people", column: "observer_id", if_not_exists: true
    add_foreign_key "observees", "observations", if_not_exists: true
    add_foreign_key "observees", "teammates", if_not_exists: true
    add_foreign_key "one_on_one_links", "teammates", if_not_exists: true
    add_foreign_key "organizations", "teammates", column: "observable_moment_notifier_teammate_id", if_not_exists: true
    add_foreign_key "page_visits", "people", if_not_exists: true
    add_foreign_key "person_identities", "people", if_not_exists: true
    add_foreign_key "position_abilities", "abilities", if_not_exists: true
    add_foreign_key "position_abilities", "positions", if_not_exists: true
    add_foreign_key "position_assignments", "assignments", if_not_exists: true
    add_foreign_key "position_assignments", "positions", if_not_exists: true
    add_foreign_key "position_check_ins", "employment_tenures", if_not_exists: true
    add_foreign_key "position_check_ins", "maap_snapshots", if_not_exists: true
    add_foreign_key "position_check_ins", "teammates", if_not_exists: true
    add_foreign_key "position_levels", "position_major_levels", if_not_exists: true
    add_foreign_key "positions", "position_levels", if_not_exists: true
    add_foreign_key "positions", "titles", if_not_exists: true
    add_foreign_key "prompt_answers", "prompt_questions", if_not_exists: true
    add_foreign_key "prompt_answers", "prompts", if_not_exists: true
    add_foreign_key "prompt_answers", "teammates", column: "updated_by_company_teammate_id", if_not_exists: true
    add_foreign_key "prompt_goals", "goals", if_not_exists: true
    add_foreign_key "prompt_goals", "prompts", if_not_exists: true
    add_foreign_key "prompt_questions", "prompt_templates", if_not_exists: true
    add_foreign_key "prompt_templates", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "prompts", "prompt_templates", if_not_exists: true
    add_foreign_key "prompts", "teammates", column: "company_teammate_id", if_not_exists: true
    add_foreign_key "seats", "seats", column: "reports_to_seat_id", if_not_exists: true
    add_foreign_key "seats", "teams", if_not_exists: true
    add_foreign_key "seats", "titles", if_not_exists: true
    add_foreign_key "slack_configurations", "organizations", if_not_exists: true
    add_foreign_key "slack_configurations", "people", column: "created_by_id", if_not_exists: true
    add_foreign_key "team_asana_links", "teams", if_not_exists: true
    add_foreign_key "team_members", "teammates", column: "company_teammate_id", if_not_exists: true
    add_foreign_key "team_members", "teams", if_not_exists: true
    add_foreign_key "teammate_identities", "teammates", if_not_exists: true
    add_foreign_key "teammate_milestones", "abilities", if_not_exists: true
    add_foreign_key "teammate_milestones", "teammates", if_not_exists: true
    add_foreign_key "teammate_milestones", "teammates", column: "certifying_teammate_id", if_not_exists: true
    add_foreign_key "teammate_milestones", "teammates", column: "published_by_teammate_id", if_not_exists: true
    add_foreign_key "teammates", "organizations", if_not_exists: true
    add_foreign_key "teammates", "people", if_not_exists: true
    add_foreign_key "teams", "departments", if_not_exists: true
    add_foreign_key "teams", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "third_party_object_associations", "third_party_objects", if_not_exists: true
    add_foreign_key "third_party_objects", "organizations", if_not_exists: true
    add_foreign_key "titles", "departments", if_not_exists: true
    add_foreign_key "titles", "organizations", column: "company_id", if_not_exists: true
    add_foreign_key "titles", "position_major_levels", if_not_exists: true
    add_foreign_key "user_preferences", "people", if_not_exists: true
  end
end
