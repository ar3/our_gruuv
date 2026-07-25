class CreateSeatTitles < ActiveRecord::Migration[8.0]
  def up
    create_table :seat_titles do |t|
      t.references :seat, null: false, foreign_key: true
      t.references :title, null: false, foreign_key: true

      t.timestamps
    end

    add_index :seat_titles, [:seat_id, :title_id], unique: true

    execute <<~SQL.squish
      INSERT INTO seat_titles (seat_id, title_id, created_at, updated_at)
      SELECT id, title_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM seats
      WHERE title_id IS NOT NULL
      ON CONFLICT (seat_id, title_id) DO NOTHING
    SQL
  end

  def down
    drop_table :seat_titles
  end
end
