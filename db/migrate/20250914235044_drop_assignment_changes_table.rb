class DropAssignmentChangesTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :assignment_changes do |t|
      t.bigint "person_id", null: false
      t.bigint "assignment_id"
      t.jsonb "request_data", null: false
      t.text "reason"
      t.bigint "created_by_id", null: false
      t.string "status", default: "pending"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["assignment_id"], name: "index_assignment_changes_on_assignment_id"
      t.index ["created_by_id"], name: "index_assignment_changes_on_created_by_id"
      t.index ["person_id"], name: "index_assignment_changes_on_person_id"
      t.index ["request_data"], name: "index_assignment_changes_on_request_data", using: :gin
      t.index ["status"], name: "index_assignment_changes_on_status"
    end
  end
end