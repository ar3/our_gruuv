class CreateIncomingWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :incoming_webhooks do |t|
      t.string :provider
      t.string :event_type
      t.string :status
      t.jsonb :payload
      t.jsonb :headers
      t.bigint :organization_id
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end
  end
end
