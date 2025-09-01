class CreateAssignmentAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_abilities do |t|
      t.references :assignment, null: false, foreign_key: true
      t.references :ability, null: false, foreign_key: true
      t.integer :milestone_level, null: false

      t.timestamps
    end

    add_index :assignment_abilities, [:assignment_id, :ability_id], unique: true, name: 'index_assignment_abilities_on_assignment_and_ability_unique'
    add_index :assignment_abilities, :milestone_level
  end
end
