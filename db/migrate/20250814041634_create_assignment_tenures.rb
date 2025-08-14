class CreateAssignmentTenures < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_tenures do |t|
      t.references :person, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.date :started_at, null: false
      t.date :ended_at
      t.integer :anticipated_energy_percentage

      t.timestamps
    end

    # Add constraints
    add_check_constraint :assignment_tenures, 
                        "anticipated_energy_percentage IS NULL OR (anticipated_energy_percentage >= 0 AND anticipated_energy_percentage <= 100)",
                        name: "check_anticipated_energy_percentage_range"
    
    # Add index for efficient queries
    add_index :assignment_tenures, [:person_id, :assignment_id, :started_at]
  end
end
