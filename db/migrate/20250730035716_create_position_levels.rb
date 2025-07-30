class CreatePositionLevels < ActiveRecord::Migration[8.0]
  def change
    create_table :position_levels do |t|
      t.references :position_major_level, null: false, foreign_key: true
      t.string :level, null: false
      t.text :ideal_assignment_goal_types

      t.timestamps
    end

    add_index :position_levels, [:position_major_level_id, :level], unique: true
  end
end
