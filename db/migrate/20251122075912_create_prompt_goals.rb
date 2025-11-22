class CreatePromptGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_goals do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :goal, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :prompt_goals, [:prompt_id, :goal_id], unique: true
  end
end
