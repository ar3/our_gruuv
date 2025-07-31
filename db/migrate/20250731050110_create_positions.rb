class CreatePositions < ActiveRecord::Migration[8.0]
  def change
    create_table :positions do |t|
      t.references :position_type, null: false, foreign_key: true
      t.references :position_level, null: false, foreign_key: true
      t.text :position_summary

      t.timestamps
    end
    
    add_index :positions, [:position_type_id, :position_level_id], unique: true, name: 'index_positions_on_type_and_level_unique'
  end
end
