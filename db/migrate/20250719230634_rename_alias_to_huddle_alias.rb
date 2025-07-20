class RenameAliasToHuddleAlias < ActiveRecord::Migration[8.0]
  def change
    rename_column :huddles, :alias, :huddle_alias
  end
end
