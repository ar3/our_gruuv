class AddCachedSlackMessageTextToIncomingWebhooks < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:incoming_webhooks, :cached_slack_message_text)

    add_column :incoming_webhooks, :cached_slack_message_text, :text
  end
end
