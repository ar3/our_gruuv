class AddResultableToIncomingWebhooks < ActiveRecord::Migration[8.0]
  def change
    add_reference :incoming_webhooks, :resultable, polymorphic: true, null: true, index: true
  end
end
