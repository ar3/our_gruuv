class CreateHuddleFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :huddle_feedbacks do |t|
      t.references :huddle, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.integer :informed_rating
      t.integer :connected_rating
      t.integer :goals_rating
      t.integer :valuable_rating
      t.string :personal_conflict_style
      t.string :team_conflict_style
      t.text :appreciation
      t.text :change_suggestion
      t.text :private_department_head
      t.text :private_facilitator
      t.boolean :anonymous

      t.timestamps
    end
  end
end
