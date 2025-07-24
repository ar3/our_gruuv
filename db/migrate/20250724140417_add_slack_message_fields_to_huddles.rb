class AddSlackMessageFieldsToHuddles < ActiveRecord::Migration[8.0]
  def change
    add_column :huddles, :announcement_message_id, :string
    add_column :huddles, :summary_message_id, :string
  end
end
