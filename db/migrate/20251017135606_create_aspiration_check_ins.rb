class CreateAspirationCheckIns < ActiveRecord::Migration[8.0]
  def change
    create_table :aspiration_check_ins do |t|
      t.references :teammate, null: false, foreign_key: true
      t.references :aspiration, null: false, foreign_key: true
      t.date :check_in_started_on, null: false
      t.string :employee_rating
      t.string :manager_rating
      t.string :official_rating
      t.text :employee_private_notes
      t.text :manager_private_notes
      t.text :shared_notes
      t.datetime :employee_completed_at
      t.datetime :manager_completed_at
      t.references :manager_completed_by, null: true, foreign_key: { to_table: :people }
      t.references :finalized_by, null: true, foreign_key: { to_table: :people }
      t.datetime :official_check_in_completed_at
      t.references :maap_snapshot, null: true, foreign_key: true

      t.timestamps
    end
    
    add_index :aspiration_check_ins, [:teammate_id, :aspiration_id, :official_check_in_completed_at], 
              name: 'index_aspiration_check_ins_on_teammate_aspiration_open'
    add_index :aspiration_check_ins, :check_in_started_on
  end
end
