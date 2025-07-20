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

ActiveRecord::Schema[8.0].define(version: 2025_07_20_162144) do
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

  create_table "huddles", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.datetime "started_at"
    t.string "huddle_alias"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["unique_textable_phone_number"], name: "index_people_on_unique_textable_phone_number", unique: true
  end

  add_foreign_key "huddle_feedbacks", "huddles"
  add_foreign_key "huddle_feedbacks", "people"
  add_foreign_key "huddle_participants", "huddles"
  add_foreign_key "huddle_participants", "people"
  add_foreign_key "huddles", "organizations"
  add_foreign_key "organizations", "organizations", column: "parent_id"
end
