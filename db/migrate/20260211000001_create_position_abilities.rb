# frozen_string_literal: true

class CreatePositionAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :position_abilities do |t|
      t.references :position, null: false, foreign_key: true
      t.references :ability, null: false, foreign_key: true
      t.integer :milestone_level, null: false

      t.timestamps
    end

    add_index :position_abilities, [:position_id, :ability_id],
              unique: true,
              name: 'index_position_abilities_on_position_and_ability_unique'
    add_index :position_abilities, :milestone_level
  end
end
