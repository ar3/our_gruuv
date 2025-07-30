class CreatePositionMajorLevels < ActiveRecord::Migration[8.0]
  def change
    create_table :position_major_levels do |t|
      t.string :description
      t.integer :major_level, null: false
      t.string :set_name, null: false

      t.timestamps
    end

    add_index :position_major_levels, [:set_name, :major_level], unique: true
  end
end
