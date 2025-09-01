class CreatePersonMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :person_milestones do |t|
      t.references :person, null: false, foreign_key: true
      t.references :ability, null: false, foreign_key: true
      t.integer :milestone_level, null: false
      t.references :certified_by, null: false, foreign_key: { to_table: :people }
      t.date :attained_at, null: false

      t.timestamps
    end

    add_index :person_milestones, [:person_id, :ability_id, :milestone_level], unique: true, name: 'index_person_milestones_on_person_ability_milestone_unique'
    add_index :person_milestones, :milestone_level
    add_index :person_milestones, :attained_at
  end
end
