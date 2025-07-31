class CreatePositionAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :position_assignments do |t|
      t.references :position, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.string :assignment_type, null: false

      t.timestamps
    end
    
    add_index :position_assignments, [:position_id, :assignment_id], unique: true, name: 'index_position_assignments_on_position_and_assignment_unique'
    add_index :position_assignments, :assignment_type
  end
end
