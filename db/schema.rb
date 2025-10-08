# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_08_112431) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "abilities", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.string "semantic_version", default: "1.0.0", null: false
    t.bigint "organization_id", null: false
    t.bigint "created_by_id", null: false
    t.bigint "updated_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "milestone_1_description"
    t.text "milestone_2_description"
    t.text "milestone_3_description"
    t.text "milestone_4_description"
    t.text "milestone_5_description"
    t.datetime "became_public_at"
    t.index ["became_public_at"], name: "index_abilities_on_became_public_at"
    t.index ["created_by_id"], name: "index_abilities_on_created_by_id"
    t.index ["name", "organization_id"], name: "index_abilities_on_name_and_organization_id", unique: true
    t.index ["organization_id"], name: "index_abilities_on_organization_id"
    t.index ["updated_by_id"], name: "index_abilities_on_updated_by_id"
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "address_type", default: "home", null: false
    t.string "street_address"
    t.string "city"
    t.string "state_province"
    t.string "postal_code"
    t.string "country"
    t.boolean "is_primary", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_addresses_on_person_id"
  end

  create_table "aspirations", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "organization_id", null: false
    t.integer "sort_order", default: 999, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_aspirations_on_deleted_at"
    t.index ["organization_id", "name"], name: "index_aspirations_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_aspirations_on_organization_id"
    t.index ["sort_order"], name: "index_aspirations_on_sort_order"
  end

  create_table "assignment_abilities", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "ability_id", null: false
    t.integer "milestone_level", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ability_id"], name: "index_assignment_abilities_on_ability_id"
    t.index ["assignment_id", "ability_id"], name: "index_assignment_abilities_on_assignment_and_ability_unique", unique: true
    t.index ["assignment_id"], name: "index_assignment_abilities_on_assignment_id"
    t.index ["milestone_level"], name: "index_assignment_abilities_on_milestone_level"
  end

  create_table "assignment_check_ins", force: :cascade do |t|
    t.date "check_in_started_on", null: false
    t.integer "actual_energy_percentage"
    t.string "employee_rating"
    t.string "manager_rating"
    t.string "official_rating"
    t.text "employee_private_notes"
    t.text "manager_private_notes"
    t.text "shared_notes"
    t.string "employee_personal_alignment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assignment_id", null: false
    t.datetime "employee_completed_at"
    t.datetime "manager_completed_at"
    t.datetime "official_check_in_completed_at"
    t.integer "manager_completed_by_id"
    t.integer "finalized_by_id"
    t.bigint "teammate_id"
    t.index ["assignment_id", "check_in_started_on"], name: "idx_on_assignment_id_check_in_started_on_9b32849637"
    t.index ["assignment_id"], name: "index_assignment_check_ins_on_assignment_id"
    t.index ["employee_completed_at"], name: "index_assignment_check_ins_on_employee_completed_at"
    t.index ["finalized_by_id"], name: "index_assignment_check_ins_on_finalized_by_id"
    t.index ["manager_completed_at"], name: "index_assignment_check_ins_on_manager_completed_at"
    t.index ["manager_completed_by_id"], name: "index_assignment_check_ins_on_manager_completed_by_id"
    t.index ["official_check_in_completed_at"], name: "index_assignment_check_ins_on_official_check_in_completed_at"
    t.index ["teammate_id"], name: "index_assignment_check_ins_on_teammate_id"
    t.check_constraint "actual_energy_percentage IS NULL OR actual_energy_percentage >= 0 AND actual_energy_percentage <= 100", name: "check_actual_energy_percentage_range"
  end

  create_table "assignment_outcomes", force: :cascade do |t|
    t.text "description"
    t.bigint "assignment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "outcome_type"
    t.index ["assignment_id"], name: "index_assignment_outcomes_on_assignment_id"
  end

  create_table "assignment_tenures", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.date "started_at", null: false
    t.date "ended_at"
    t.integer "anticipated_energy_percentage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "teammate_id"
    t.index ["assignment_id"], name: "index_assignment_tenures_on_assignment_id"
    t.index ["teammate_id"], name: "index_assignment_tenures_on_teammate_id"
    t.check_constraint "anticipated_energy_percentage IS NULL OR anticipated_energy_percentage >= 0 AND anticipated_energy_percentage <= 100", name: "check_anticipated_energy_percentage_range"
  end

  create_table "assignments", force: :cascade do |t|
    t.string "title"
    t.text "tagline"
    t.text "required_activities"
    t.text "handbook"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "became_public_at"
    t.index ["became_public_at"], name: "index_assignments_on_became_public_at"
    t.index ["company_id"], name: "index_assignments_on_company_id"
  end

  create_table "debug_responses", force: :cascade do |t|
    t.jsonb "request"
    t.jsonb "response"
    t.string "responseable_type", null: false
    t.bigint "responseable_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["responseable_type", "responseable_id"], name: "index_debug_responses_on_responseable"
  end

  create_table "employment_tenures", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "position_id", null: false
    t.bigint "manager_id"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "employment_change_notes"
    t.bigint "seat_id"
    t.bigint "teammate_id"
    t.string "employment_type", default: "full_time"
    t.index ["company_id"], name: "index_employment_tenures_on_company_id"
    t.index ["manager_id"], name: "index_employment_tenures_on_manager_id"
    t.index ["position_id"], name: "index_employment_tenures_on_position_id"
    t.index ["seat_id"], name: "index_employment_tenures_on_seat_id"
    t.index ["teammate_id"], name: "index_employment_tenures_on_teammate_id"
  end

  create_table "external_references", force: :cascade do |t|
    t.string "referable_type", null: false
    t.bigint "referable_id", null: false
    t.string "url"
    t.jsonb "source_data"
    t.datetime "last_synced_at"
    t.string "reference_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["referable_type", "referable_id", "reference_type"], name: "index_external_references_on_referable_and_type"
    t.index ["referable_type", "referable_id"], name: "index_external_references_on_referable"
  end

  create_table "huddle_feedbacks", force: :cascade do |t|
    t.bigint "huddle_id", null: false
    t.integer "informed_rating"
    t.integer "connected_rating"
    t.integer "goals_rating"
    t.integer "valuable_rating"
    t.string "personal_conflict_style"
    t.string "team_conflict_style"
    t.text "appreciation"
    t.text "change_suggestion"
    t.text "private_department_head"
    t.text "private_facilitator"
    t.boolean "anonymous"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "teammate_id"
    t.index ["huddle_id"], name: "index_huddle_feedbacks_on_huddle_id"
    t.index ["teammate_id"], name: "index_huddle_feedbacks_on_teammate_id"
  end

  create_table "huddle_participants", force: :cascade do |t|
    t.bigint "huddle_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "teammate_id"
    t.index ["huddle_id"], name: "index_huddle_participants_on_huddle_id"
    t.index ["teammate_id"], name: "index_huddle_participants_on_teammate_id"
  end

  create_table "huddle_playbooks", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "special_session_name"
    t.string "slack_channel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "special_session_name"], name: "index_huddle_playbooks_on_org_and_special_session_name_unique", unique: true
    t.index ["organization_id"], name: "index_huddle_playbooks_on_organization_id"
  end

  create_table "huddles", force: :cascade do |t|
    t.datetime "started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'PT24H'::interval)" }, null: false
    t.bigint "huddle_playbook_id"
    t.index ["expires_at"], name: "index_huddles_on_expires_at"
    t.index ["huddle_playbook_id"], name: "index_huddles_on_huddle_playbook_id"
  end

  create_table "interest_submissions", force: :cascade do |t|
    t.text "thing_interested_in"
    t.text "why_interested"
    t.text "current_solution"
    t.string "source_page"
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_interest_submissions_on_person_id"
  end

  create_table "maap_snapshots", force: :cascade do |t|
    t.bigint "employee_id"
    t.bigint "created_by_id"
    t.bigint "company_id"
    t.string "change_type", null: false
    t.text "reason", null: false
    t.jsonb "maap_data", default: {}
    t.jsonb "request_info", default: {}, null: false
    t.date "effective_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "form_params"
    t.index ["change_type"], name: "index_maap_snapshots_on_change_type"
    t.index ["company_id"], name: "index_maap_snapshots_on_company_id"
    t.index ["created_by_id"], name: "index_maap_snapshots_on_created_by_id"
    t.index ["effective_date"], name: "index_maap_snapshots_on_effective_date"
    t.index ["employee_id"], name: "index_maap_snapshots_on_employee_id"
    t.index ["maap_data"], name: "index_maap_snapshots_on_maap_data", using: :gin
    t.index ["request_info"], name: "index_maap_snapshots_on_request_info", using: :gin
  end

  create_table "notifications", force: :cascade do |t|
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.bigint "main_thread_id"
    t.bigint "original_message_id"
    t.string "notification_type"
    t.string "message_id"
    t.string "status"
    t.jsonb "metadata"
    t.jsonb "rich_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "fallback_text"
    t.index ["main_thread_id"], name: "index_notifications_on_main_thread_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["original_message_id"], name: "index_notifications_on_original_message_id"
  end

  create_table "observation_ratings", force: :cascade do |t|
    t.bigint "observation_id", null: false
    t.string "rateable_type", null: false
    t.bigint "rateable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "rating", default: "na", null: false
    t.index ["observation_id", "rateable_type", "rateable_id"], name: "index_observation_ratings_unique", unique: true
    t.index ["observation_id"], name: "index_observation_ratings_on_observation_id"
    t.index ["rateable_type", "rateable_id"], name: "index_observation_ratings_on_rateable"
    t.index ["rateable_type", "rateable_id"], name: "index_observation_ratings_on_rateable_type_and_rateable_id"
  end

  create_table "observations", force: :cascade do |t|
    t.bigint "observer_id", null: false
    t.bigint "company_id", null: false
    t.text "story", null: false
    t.string "primary_feeling"
    t.string "secondary_feeling"
    t.datetime "observed_at"
    t.string "custom_slug"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "privacy_level", default: "observer_only", null: false
    t.index ["company_id"], name: "index_observations_on_company_id"
    t.index ["custom_slug"], name: "index_observations_on_custom_slug", unique: true
    t.index ["deleted_at"], name: "index_observations_on_deleted_at"
    t.index ["observed_at", "id"], name: "index_observations_on_observed_at_and_id"
    t.index ["observed_at"], name: "index_observations_on_observed_at"
    t.index ["observer_id"], name: "index_observations_on_observer_id"
  end

  create_table "observees", force: :cascade do |t|
    t.bigint "observation_id", null: false
    t.bigint "teammate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["observation_id", "teammate_id"], name: "index_observees_on_observation_id_and_teammate_id", unique: true
    t.index ["observation_id"], name: "index_observees_on_observation_id"
    t.index ["teammate_id"], name: "index_observees_on_teammate_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_organizations_on_parent_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.string "suffix"
    t.string "unique_textable_phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "timezone"
    t.integer "current_organization_id"
    t.boolean "og_admin", default: false, null: false
    t.string "preferred_name"
    t.string "gender_identity"
    t.string "pronouns"
    t.string "slack_user_id"
    t.index ["current_organization_id"], name: "index_people_on_current_organization_id"
    t.index ["og_admin"], name: "index_people_on_og_admin"
    t.index ["unique_textable_phone_number"], name: "index_people_on_unique_textable_phone_number", unique: true
  end

  create_table "person_identities", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "profile_image_url"
    t.jsonb "raw_data"
    t.index ["email"], name: "index_person_identities_on_email"
    t.index ["person_id", "provider"], name: "index_person_identities_on_person_id_and_provider"
    t.index ["person_id"], name: "index_person_identities_on_person_id"
    t.index ["provider", "uid"], name: "index_person_identities_on_provider_and_uid", unique: true
  end

  create_table "person_milestones", force: :cascade do |t|
    t.bigint "ability_id", null: false
    t.integer "milestone_level", null: false
    t.bigint "certified_by_id", null: false
    t.date "attained_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "teammate_id"
    t.index ["ability_id"], name: "index_person_milestones_on_ability_id"
    t.index ["attained_at"], name: "index_person_milestones_on_attained_at"
    t.index ["certified_by_id"], name: "index_person_milestones_on_certified_by_id"
    t.index ["milestone_level"], name: "index_person_milestones_on_milestone_level"
    t.index ["teammate_id"], name: "index_person_milestones_on_teammate_id"
  end

  create_table "position_assignments", force: :cascade do |t|
    t.bigint "position_id", null: false
    t.bigint "assignment_id", null: false
    t.string "assignment_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "min_estimated_energy"
    t.integer "max_estimated_energy"
    t.integer "anticipated_energy_percentage"
    t.index ["assignment_id"], name: "index_position_assignments_on_assignment_id"
    t.index ["assignment_type"], name: "index_position_assignments_on_assignment_type"
    t.index ["position_id", "assignment_id"], name: "index_position_assignments_on_position_and_assignment_unique", unique: true
    t.index ["position_id"], name: "index_position_assignments_on_position_id"
    t.check_constraint "anticipated_energy_percentage IS NULL OR anticipated_energy_percentage >= 0 AND anticipated_energy_percentage <= 100", name: "check_anticipated_energy_percentage_range"
  end

  create_table "position_levels", force: :cascade do |t|
    t.bigint "position_major_level_id", null: false
    t.string "level", null: false
    t.text "ideal_assignment_goal_types"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position_major_level_id", "level"], name: "index_position_levels_on_position_major_level_id_and_level", unique: true
    t.index ["position_major_level_id"], name: "index_position_levels_on_position_major_level_id"
  end

  create_table "position_major_levels", force: :cascade do |t|
    t.string "description"
    t.integer "major_level", null: false
    t.string "set_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["set_name", "major_level"], name: "index_position_major_levels_on_set_name_and_major_level", unique: true
  end

  create_table "position_types", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "position_major_level_id", null: false
    t.string "external_title", null: false
    t.text "alternative_titles"
    t.text "position_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "position_major_level_id", "external_title"], name: "index_position_types_on_org_level_title_unique", unique: true
    t.index ["organization_id"], name: "index_position_types_on_organization_id"
    t.index ["position_major_level_id"], name: "index_position_types_on_position_major_level_id"
  end

  create_table "positions", force: :cascade do |t|
    t.bigint "position_type_id", null: false
    t.bigint "position_level_id", null: false
    t.text "position_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "became_public_at"
    t.index ["became_public_at"], name: "index_positions_on_became_public_at"
    t.index ["position_level_id"], name: "index_positions_on_position_level_id"
    t.index ["position_type_id", "position_level_id"], name: "index_positions_on_type_and_level_unique", unique: true
    t.index ["position_type_id"], name: "index_positions_on_position_type_id"
  end

  create_table "seats", force: :cascade do |t|
    t.bigint "position_type_id", null: false
    t.date "seat_needed_by", null: false
    t.string "job_classification", default: "Salaried Exempt"
    t.string "reports_to"
    t.string "team"
    t.text "reports"
    t.text "measurable_outcomes"
    t.text "work_environment", default: "Prolonged periods of sitting at a desk and working on a computer."
    t.text "physical_requirements", default: "While performing the duties of this job, the employee may be regularly required to stand, sit, talk, hear, and use hands and fingers to operate a computer and keyboard. Specific vision abilities required by this job include close vision requirements due to computer work."
    t.text "travel", default: "Travel is on a voluntary basis."
    t.text "why_needed"
    t.text "why_now"
    t.text "costs_risks"
    t.string "state", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "seat_disclaimer", default: "This job description is not designed to cover or contain a comprehensive list of duties or responsibilities. Duties may change or new ones may be assigned at any time."
    t.index ["position_type_id", "seat_needed_by"], name: "index_seats_on_position_type_and_needed_by", unique: true
    t.index ["position_type_id"], name: "index_seats_on_position_type_id"
  end

  create_table "slack_configurations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "workspace_id", null: false
    t.string "workspace_name", null: false
    t.string "bot_token", null: false
    t.string "default_channel", default: "#general"
    t.string "bot_username", default: "Huddle Bot"
    t.string "bot_emoji", default: ":huddle:"
    t.datetime "installed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bot_user_id"
    t.string "workspace_url"
    t.string "workspace_subdomain"
    t.index ["bot_token"], name: "index_slack_configurations_on_bot_token", unique: true
    t.index ["organization_id"], name: "index_slack_configurations_on_organization_id"
    t.index ["workspace_id"], name: "index_slack_configurations_on_workspace_id", unique: true
  end

  create_table "teammate_identities", force: :cascade do |t|
    t.bigint "teammate_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email"
    t.string "name"
    t.string "profile_image_url"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_teammate_identities_on_provider_and_uid", unique: true
    t.index ["teammate_id", "provider"], name: "index_teammate_identities_on_teammate_and_provider"
    t.index ["teammate_id"], name: "index_teammate_identities_on_teammate_id"
  end

  create_table "teammates", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "organization_id", null: false
    t.boolean "can_manage_employment"
    t.boolean "can_manage_maap"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "can_create_employment"
    t.datetime "first_employed_at"
    t.datetime "last_terminated_at"
    t.string "type"
    t.index ["can_manage_employment"], name: "index_teammates_on_can_manage_employment"
    t.index ["can_manage_maap"], name: "index_teammates_on_can_manage_maap"
    t.index ["first_employed_at", "last_terminated_at"], name: "index_teammates_on_first_employed_at_and_last_terminated_at"
    t.index ["first_employed_at"], name: "index_teammates_on_first_employed_at"
    t.index ["last_terminated_at"], name: "index_teammates_on_last_terminated_at"
    t.index ["organization_id"], name: "index_teammates_on_organization_id"
    t.index ["person_id", "organization_id"], name: "index_person_org_access_on_person_and_org", unique: true
    t.index ["person_id"], name: "index_teammates_on_person_id"
  end

  create_table "third_party_object_associations", force: :cascade do |t|
    t.bigint "third_party_object_id", null: false
    t.string "associatable_type", null: false
    t.bigint "associatable_id", null: false
    t.string "association_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["associatable_type", "associatable_id", "association_type"], name: "index_third_party_associations_on_associatable_and_type", unique: true
    t.index ["associatable_type", "associatable_id"], name: "index_third_party_object_associations_on_associatable"
    t.index ["third_party_object_id", "association_type"], name: "index_third_party_associations_on_object_and_type"
    t.index ["third_party_object_id"], name: "index_third_party_object_associations_on_third_party_object_id"
  end

  create_table "third_party_objects", force: :cascade do |t|
    t.string "display_name", null: false
    t.string "third_party_name", null: false
    t.string "third_party_id", null: false
    t.string "third_party_object_type", null: false
    t.string "third_party_source", null: false
    t.bigint "organization_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "third_party_id", "third_party_source"], name: "index_third_party_objects_on_org_third_party_id_source", unique: true
    t.index ["organization_id", "third_party_source", "deleted_at"], name: "index_third_party_objects_on_org_source_deleted"
    t.index ["organization_id"], name: "index_third_party_objects_on_organization_id"
  end

  create_table "upload_events", force: :cascade do |t|
    t.text "file_content"
    t.jsonb "preview_actions", default: {}
    t.bigint "creator_id", null: false
    t.bigint "initiator_id", null: false
    t.datetime "attempted_at"
    t.string "status", default: "preview", null: false
    t.jsonb "results", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.string "filename"
    t.string "type"
    t.index ["created_at"], name: "index_upload_events_on_created_at"
    t.index ["creator_id"], name: "index_upload_events_on_creator_id"
    t.index ["initiator_id"], name: "index_upload_events_on_initiator_id"
    t.index ["organization_id"], name: "index_upload_events_on_organization_id"
    t.index ["status"], name: "index_upload_events_on_status"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.jsonb "meta"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "abilities", "organizations"
  add_foreign_key "abilities", "people", column: "created_by_id"
  add_foreign_key "abilities", "people", column: "updated_by_id"
  add_foreign_key "addresses", "people"
  add_foreign_key "aspirations", "organizations"
  add_foreign_key "assignment_abilities", "abilities"
  add_foreign_key "assignment_abilities", "assignments"
  add_foreign_key "assignment_check_ins", "assignments"
  add_foreign_key "assignment_check_ins", "people", column: "finalized_by_id"
  add_foreign_key "assignment_check_ins", "teammates"
  add_foreign_key "assignment_outcomes", "assignments"
  add_foreign_key "assignment_tenures", "assignments"
  add_foreign_key "assignment_tenures", "teammates"
  add_foreign_key "assignments", "organizations", column: "company_id"
  add_foreign_key "employment_tenures", "organizations", column: "company_id"
  add_foreign_key "employment_tenures", "people", column: "manager_id"
  add_foreign_key "employment_tenures", "positions"
  add_foreign_key "employment_tenures", "seats"
  add_foreign_key "employment_tenures", "teammates"
  add_foreign_key "huddle_feedbacks", "huddles"
  add_foreign_key "huddle_feedbacks", "teammates"
  add_foreign_key "huddle_participants", "huddles"
  add_foreign_key "huddle_participants", "teammates"
  add_foreign_key "huddle_playbooks", "organizations"
  add_foreign_key "huddles", "huddle_playbooks"
  add_foreign_key "interest_submissions", "people"
  add_foreign_key "maap_snapshots", "organizations", column: "company_id"
  add_foreign_key "maap_snapshots", "people", column: "created_by_id"
  add_foreign_key "maap_snapshots", "people", column: "employee_id"
  add_foreign_key "notifications", "notifications", column: "main_thread_id"
  add_foreign_key "notifications", "notifications", column: "original_message_id"
  add_foreign_key "observation_ratings", "observations"
  add_foreign_key "observations", "organizations", column: "company_id"
  add_foreign_key "observations", "people", column: "observer_id"
  add_foreign_key "observees", "observations"
  add_foreign_key "observees", "teammates"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "people", "organizations", column: "current_organization_id"
  add_foreign_key "person_identities", "people"
  add_foreign_key "person_milestones", "abilities"
  add_foreign_key "person_milestones", "teammates"
  add_foreign_key "position_assignments", "assignments"
  add_foreign_key "position_assignments", "positions"
  add_foreign_key "position_levels", "position_major_levels"
  add_foreign_key "position_types", "organizations"
  add_foreign_key "position_types", "position_major_levels"
  add_foreign_key "positions", "position_levels"
  add_foreign_key "positions", "position_types"
  add_foreign_key "seats", "position_types"
  add_foreign_key "slack_configurations", "organizations"
  add_foreign_key "teammate_identities", "teammates"
  add_foreign_key "teammates", "organizations"
  add_foreign_key "teammates", "people"
  add_foreign_key "third_party_object_associations", "third_party_objects"
  add_foreign_key "third_party_objects", "organizations"
  add_foreign_key "upload_events", "organizations"
  add_foreign_key "upload_events", "people", column: "creator_id"
  add_foreign_key "upload_events", "people", column: "initiator_id"
end
