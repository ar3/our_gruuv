class RemoveHuddleAliasFromHuddles < ActiveRecord::Migration[8.0]
  def change
    remove_column :huddles, :huddle_alias, :string
  end
end
