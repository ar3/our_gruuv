class AddStoryExtrasToObservations < ActiveRecord::Migration[8.0]
  def change
    add_column :observations, :story_extras, :jsonb, default: {}
    add_index :observations, :story_extras, using: :gin
  end
end
