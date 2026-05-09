class AddGsdNotificationSkippedAtToObservations < ActiveRecord::Migration[8.0]
  def change
    add_column :observations, :gsd_notification_skipped_at, :datetime
  end
end
