class AddPublishedAtToObservations < ActiveRecord::Migration[8.0]
  def change
    add_column :observations, :published_at, :datetime
    add_index :observations, :published_at
  end
end
