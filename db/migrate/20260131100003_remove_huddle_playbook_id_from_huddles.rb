class RemoveHuddlePlaybookIdFromHuddles < ActiveRecord::Migration[8.0]
  def change
    remove_reference :huddles, :huddle_playbook, foreign_key: true
  end
end
