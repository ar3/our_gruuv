class CreateHuddles < ActiveRecord::Migration[8.0]
  def change
    create_table :huddles do |t|
      t.references :organization, null: false, foreign_key: true
      t.datetime :started_at
      t.string :alias

      t.timestamps
    end
  end
end
