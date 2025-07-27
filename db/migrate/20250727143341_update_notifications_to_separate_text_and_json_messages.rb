class UpdateNotificationsToSeparateTextAndJsonMessages < ActiveRecord::Migration[8.0]
  def change
    # Rename the existing message column to rich_message
    rename_column :notifications, :message, :rich_message
    
    # Add the new fallback_text column
    add_column :notifications, :fallback_text, :text
  end
end
