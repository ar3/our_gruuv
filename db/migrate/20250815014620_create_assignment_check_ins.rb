class CreateAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_check_ins do |t|
      t.references :assignment_tenure, null: false, foreign_key: true
      t.date :check_in_date, null: false
      t.integer :actual_energy_percentage
      t.string :employee_rating
      t.string :manager_rating
      t.string :official_rating
      t.text :employee_private_notes
      t.text :manager_private_notes
      t.text :shared_notes
      t.string :employee_personal_alignment

      t.timestamps
    end

    # Add constraints
    add_check_constraint :assignment_check_ins, 
                        "actual_energy_percentage IS NULL OR (actual_energy_percentage >= 0 AND actual_energy_percentage <= 100)",
                        name: "check_actual_energy_percentage_range"
    
    # Add index for efficient queries
    add_index :assignment_check_ins, [:assignment_tenure_id, :check_in_date]
  end
end
