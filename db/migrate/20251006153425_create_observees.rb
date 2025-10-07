class CreateObservees < ActiveRecord::Migration[8.0]
  def change
    create_table :observees do |t|
      t.references :observation, null: false, foreign_key: true
      t.references :teammate, null: false, foreign_key: true

      t.timestamps
    end

    add_index :observees, [:observation_id, :teammate_id], unique: true, if_not_exists: true
    add_index :observees, :teammate_id, if_not_exists: true
  end
end
