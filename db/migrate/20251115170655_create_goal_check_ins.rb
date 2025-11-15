class CreateGoalCheckIns < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_check_ins do |t|
      t.references :goal, null: false, foreign_key: true
      t.date :check_in_week_start, null: false
      t.integer :confidence_percentage, null: false
      t.text :confidence_reason
      t.references :confidence_reporter, null: false, foreign_key: { to_table: :people }

      t.timestamps
    end
    
    add_index :goal_check_ins, [:goal_id, :check_in_week_start], unique: true, name: 'index_goal_check_ins_on_goal_and_week'
    add_index :goal_check_ins, :check_in_week_start
  end
end
