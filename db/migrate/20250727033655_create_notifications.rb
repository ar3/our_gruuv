class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.references :main_thread, null: true, foreign_key: { to_table: :notifications }
      t.references :original_message, null: true, foreign_key: { to_table: :notifications }
      t.string :notification_type
      t.string :message_id
      t.string :status
      t.jsonb :metadata
      t.jsonb :message

      t.timestamps
    end
  end
end
