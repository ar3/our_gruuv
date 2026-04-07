class CreateGoalAssociations < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_associations do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :associable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :goal_associations,
              [:goal_id, :associable_type, :associable_id],
              unique: true,
              name: 'index_goal_associations_on_goal_and_associable'
  end
end
