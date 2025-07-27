class RemoveMessageIdsFromHuddles < ActiveRecord::Migration[8.0]
  def change
    remove_column :huddles, :announcement_message_id, :string
    remove_column :huddles, :summary_message_id, :string
  end
end
