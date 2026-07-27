class AddDeletedAtToTitles < ActiveRecord::Migration[8.0]
  def change
    add_column :titles, :deleted_at, :datetime
    add_index :titles, :deleted_at
  end
end
