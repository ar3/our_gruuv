class CreatePositionCheckIns < ActiveRecord::Migration[8.0]
  def change
    create_table :position_check_ins do |t|
      t.references :teammate, null: false, foreign_key: true
      t.references :employment_tenure, null: false, foreign_key: true
      t.date :check_in_started_on, null: false
      
      # Employee perspective
      t.integer :employee_rating
      t.text :employee_private_notes
      t.datetime :employee_completed_at
      
      # Manager perspective
      t.integer :manager_rating
      t.text :manager_private_notes
      t.datetime :manager_completed_at
      t.references :manager_completed_by, foreign_key: { to_table: :people }
      
      # Official finalization
      t.integer :official_rating
      t.text :shared_notes
      t.datetime :official_check_in_completed_at
      t.references :finalized_by, foreign_key: { to_table: :people }
      t.references :maap_snapshot, foreign_key: true
      
      t.timestamps
    end
    
    add_index :position_check_ins, [:teammate_id, :check_in_started_on]
    add_index :position_check_ins, :employee_completed_at
    add_index :position_check_ins, :manager_completed_at
    add_index :position_check_ins, :official_check_in_completed_at
    
    add_check_constraint :position_check_ins,
      'employee_rating IS NULL OR (employee_rating >= -3 AND employee_rating <= 3)',
      name: 'valid_employee_rating_range'
      
    add_check_constraint :position_check_ins,
      'manager_rating IS NULL OR (manager_rating >= -3 AND manager_rating <= 3)',
      name: 'valid_manager_rating_range'
      
    add_check_constraint :position_check_ins,
      'official_rating IS NULL OR (official_rating >= -3 AND official_rating <= 3)',
      name: 'valid_official_rating_range'
  end
end
