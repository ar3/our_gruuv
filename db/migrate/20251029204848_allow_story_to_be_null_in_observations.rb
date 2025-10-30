class AllowStoryToBeNullInObservations < ActiveRecord::Migration[8.0]
  def change
    change_column_null :observations, :story, true
  end
end
