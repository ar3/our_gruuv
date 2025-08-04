class RenameCalorieColumnsToEnergy < ActiveRecord::Migration[8.0]
  def change
    rename_column :position_assignments, :min_estimated_calories, :min_estimated_energy
    rename_column :position_assignments, :max_estimated_calories, :max_estimated_energy
  end
end
