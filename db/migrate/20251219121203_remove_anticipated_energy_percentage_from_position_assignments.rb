class RemoveAnticipatedEnergyPercentageFromPositionAssignments < ActiveRecord::Migration[8.0]
  def change
    remove_check_constraint :position_assignments, name: "check_anticipated_energy_percentage_range"
    remove_column :position_assignments, :anticipated_energy_percentage, :integer
  end
end
