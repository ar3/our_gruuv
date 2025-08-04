class AddCalorieMetadataToPositionAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :position_assignments, :min_estimated_calories, :integer
    add_column :position_assignments, :max_estimated_calories, :integer
  end
end
