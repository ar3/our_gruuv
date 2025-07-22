class AddSlackChannelToHuddles < ActiveRecord::Migration[8.0]
  def change
    add_column :huddles, :slack_channel, :string
  end
end
