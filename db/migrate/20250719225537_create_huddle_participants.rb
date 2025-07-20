class CreateHuddleParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :huddle_participants do |t|
      t.references :huddle, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end
  end
end
