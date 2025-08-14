class AddAnticipatedEnergyPercentageToPositionAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :position_assignments, :anticipated_energy_percentage, :integer
    
    # Add a check constraint to ensure percentage is between 0-100
    add_check_constraint :position_assignments, 
                        "anticipated_energy_percentage IS NULL OR (anticipated_energy_percentage >= 0 AND anticipated_energy_percentage <= 100)",
                        name: "check_anticipated_energy_percentage_range"
  end
end
