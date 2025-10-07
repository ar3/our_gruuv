class CreateObservationRatings < ActiveRecord::Migration[8.0]
  def change
    create_table :observation_ratings do |t|
      t.references :observation, null: false, foreign_key: true
      t.references :rateable, polymorphic: true, null: false
      t.integer :rating, null: false

      t.timestamps
    end

    add_index :observation_ratings, [:observation_id, :rateable_type, :rateable_id], unique: true, name: 'index_observation_ratings_unique', if_not_exists: true
    add_index :observation_ratings, [:rateable_type, :rateable_id], if_not_exists: true
    add_index :observation_ratings, :rating, if_not_exists: true
  end
end
