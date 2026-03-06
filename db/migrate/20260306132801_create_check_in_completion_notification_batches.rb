class CreateCheckInCompletionNotificationBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :check_in_completion_notification_batches do |t|
      t.references :organization, null: false, foreign_key: true
      t.datetime :hour_marker, null: false
      t.references :employee_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :manager_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :action_taker_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :notification, null: true, foreign_key: true

      t.timestamps
    end

    add_index :check_in_completion_notification_batches,
              %i[organization_id hour_marker employee_teammate_id manager_teammate_id action_taker_teammate_id],
              unique: true,
              name: "idx_check_in_completion_batches_unique_key"
  end
end
