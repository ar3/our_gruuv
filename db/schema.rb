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

ActiveRecord::Schema[8.0].define(version: 2025_07_26_001343) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "huddle_feedbacks", force: :cascade do |t|
    t.bigint "huddle_id", null: false
    t.bigint "person_id", null: false
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
    t.index ["huddle_id", "person_id"], name: "index_huddle_feedbacks_on_huddle_and_person_unique", unique: true
    t.index ["huddle_id"], name: "index_huddle_feedbacks_on_huddle_id"
    t.index ["person_id"], name: "index_huddle_feedbacks_on_person_id"
  end

  create_table "huddle_participants", force: :cascade do |t|
    t.bigint "huddle_id", null: false
    t.bigint "person_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["huddle_id", "person_id"], name: "index_huddle_participants_on_huddle_and_person_unique", unique: true
    t.index ["huddle_id"], name: "index_huddle_participants_on_huddle_id"
    t.index ["person_id"], name: "index_huddle_participants_on_person_id"
  end

  create_table "huddle_playbooks", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "special_session_name"
    t.string "slack_channel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "special_session_name"], name: "index_huddle_playbooks_on_org_and_special_session_name", unique: true
    t.index ["organization_id"], name: "index_huddle_playbooks_on_organization_id"
  end

  create_table "huddles", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.datetime "started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'PT24H'::interval)" }, null: false
    t.bigint "huddle_playbook_id"
    t.string "announcement_message_id"
    t.string "summary_message_id"
    t.index ["expires_at"], name: "index_huddles_on_expires_at"
    t.index ["huddle_playbook_id"], name: "index_huddles_on_huddle_playbook_id"
    t.index ["organization_id"], name: "index_huddles_on_organization_id"
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
    t.index ["current_organization_id"], name: "index_people_on_current_organization_id"
    t.index ["unique_textable_phone_number"], name: "index_people_on_unique_textable_phone_number", unique: true
  end

  create_table "slack_configurations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "workspace_id", null: false
    t.string "workspace_name", null: false
    t.string "bot_token", null: false
    t.string "default_channel", default: "#bot-test"
    t.string "bot_username", default: "OG"
    t.string "bot_emoji", default: ":handshake:"
    t.datetime "installed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bot_user_id"
    t.string "workspace_url"
    t.index ["bot_token"], name: "index_slack_configurations_on_bot_token", unique: true
    t.index ["organization_id"], name: "index_slack_configurations_on_organization_id"
    t.index ["workspace_id"], name: "index_slack_configurations_on_workspace_id", unique: true
  end

  add_foreign_key "huddle_feedbacks", "huddles"
  add_foreign_key "huddle_feedbacks", "people"
  add_foreign_key "huddle_participants", "huddles"
  add_foreign_key "huddle_participants", "people"
  add_foreign_key "huddle_playbooks", "organizations"
  add_foreign_key "huddles", "huddle_playbooks"
  add_foreign_key "huddles", "organizations"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "people", "organizations", column: "current_organization_id"
  add_foreign_key "slack_configurations", "organizations"
end
