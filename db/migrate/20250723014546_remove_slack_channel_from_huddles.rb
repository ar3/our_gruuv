class RemoveSlackChannelFromHuddles < ActiveRecord::Migration[8.0]
  def change
    remove_column :huddles, :slack_channel, :string
  end
end
